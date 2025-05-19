require "/scripts/util.lua"
require "/scripts/rect.lua"
-- require "/scripts/v-world.lua"

local playerDetectRadius  -- Maximum player detection range relative to player detection position
local playerDetectOffset  -- Player detection position is based on this variable and the object's position.
local playerDetectOffset2  -- If provided, defines the other corner.
local itemDetectRadius  -- Maximum item detection range relative to dead player position.
local openWaitTime  -- The amount of time to wait after opening and before collecting the item
local postCollectWaitTime  -- The amount of time to wait after collecting.
local closeWaitTime  -- The amount of time to wait after closing and before changing the fill status.

local prevAlivePlayers
local alivePlayers

local playerPositionMap

local trackedItems
local takenItems

local collectState
local containerState

-- Open state control variables.
local shouldOpen  -- This is the only part that should be controlled outside of updateOpenState.
local wasOpened

-- HOOKS

function init()
  playerDetectRadius = config.getParameter("playerDetectRadius", 50)
  playerDetectOffset = config.getParameter("playerDetectOffset", {0, 0})
  playerDetectOffset2 = config.getParameter("playerDetectOffset2")
  itemDetectRadius = config.getParameter("itemDetectRadius", 20)
  openWaitTime = config.getParameter("openWaitTime", 0.5)
  postCollectWaitTime = config.getParameter("postCollectWaitTime", 0.5)
  closeWaitTime = config.getParameter("closeWaitTime", 0.5)

  prevAlivePlayers = {}  -- Players that were alive in the previous tick
  alivePlayers = {}  -- Players that are alive in the current tick

  playerPositionMap = {}  -- Hash map

  trackedItems = {}  -- Item entities that are still alive.
  takenItems = config.getParameter("takenItems", {})  -- Retrieve taken items from storage.

  collectState = FSM:new()
  collectState:set(collectStates.idle)

  containerState = FSM:new()
  containerState:set(containerStates.empty)

  shouldOpen = false
  wasOpened = false

  -- Set storage.isInvisible if not already set.
  if storage.isInvisible == nil then
    storage.isInvisible = config.getParameter("startsInvisible")
  end

  object.setInteractive(not storage.isInvisible)  -- Make non-interactive if invisible.
  -- Set animation state to be invisible if the object is invisible. Do nothing otherwise.
  if storage.isInvisible then
    animator.setAnimationState("chest", "invisible")
  end

  message.setHandler("open", function()
    shouldOpen = true  -- Make the updateOpenState() function open the chest in the next tick.
  end)

  message.setHandler("close", function()
    shouldOpen = false  -- Make the updateOpenState() function close the chest in the next tick.
  end)
end

function update(dt)
  -- Keep own chunk loaded
  local ownPos = object.position()
  world.loadRegion(rect.translate({-1, -1, 1, 1}, ownPos))

  prevAlivePlayers = alivePlayers
  local queryPos = {ownPos[1] + playerDetectOffset[1], ownPos[2] + playerDetectOffset[2]}
  local queryPos2
  if playerDetectOffset2 then
    queryPos2 = {ownPos[1] + playerDetectOffset2[1], ownPos[2] + playerDetectOffset2[2]}
  end
  alivePlayers = world.entityQuery(queryPos, queryPos2 or playerDetectRadius, {includedTypes = {"player"}})
  -- vWorld.debugQueryArea(queryPos, queryPos2 or playerDetectRadius, "green")

  -- Appear if invisible and at least one alive player was found.
  if storage.isInvisible and #alivePlayers > 0 then
    animator.setAnimationState("chest", "appear")
    object.setInteractive(true)
    storage.isInvisible = false
  end

  -- Check for players that have died or stopped existing between the previous update and this update. For each of those
  -- players, collect the nearby items.
  for _, playerId in ipairs(prevAlivePlayers) do
    -- If the player is no longer in alivePlayers because they stopped existing...
    if not contains(alivePlayers, playerId) and not world.entityExists(playerId) then
      trackItems(playerPositionMap[playerId])

      playerPositionMap[playerId] = nil
    end
  end

  for _, playerId in ipairs(alivePlayers) do
    playerPositionMap[playerId] = world.entityPosition(playerId)
  end

  refillContents()

  updateOpenState()
  collectState:update()
  containerState:update()
end

function uninit()
  object.setConfigParameter("takenItems", takenItems)  -- Store taken items
end

-- COLLECT STATES

collectStates = {}

function collectStates.idle()
  -- Update loop.
  while true do
    -- Transition to collectStates.collect when trackedItems is nonempty.
    if #trackedItems > 0 then
      collectState:set(collectStates.collect)
    end

    coroutine.yield()
  end
end

function collectStates.collect()
  -- Open chest for collecting.
  shouldOpen = true  -- Make the updateOpenState() function open the chest in the next tick.
  animator.playSound("open")

  util.wait(openWaitTime)

  local collectedItems = {}

  -- Try to repeatedly collect items until there are no more tracked items to collect for now. Items that stop existing
  -- are dropped altogether.
  while #trackedItems > 0 do
    collectItems(collectedItems)

    coroutine.yield()
  end

  -- Wait for items to be collected
  while #collectedItems > 0 do
    -- Filter out items that don't exist.
    collectedItems = util.filter(collectedItems, function(item) return world.entityExists(item) end)
    coroutine.yield()
  end

  collectState:set(collectStates.awaitMoreItems)
end

function collectStates.awaitMoreItems()
  util.wait(postCollectWaitTime, function()
    if #trackedItems > 0 then
      collectState:set(collectStates.collect)
    end
  end)

  -- Close
  shouldOpen = false  -- Make the updateOpenState() function close the chest in the next tick.
  animator.playSound("close")

  util.wait(closeWaitTime)

  collectState:set(collectStates.idle)
end

-- CONTAINER STATES

containerStates = {}

function containerStates.empty()
  coroutine.yield()

  animator.setAnimationState("glow", "inactive")  -- Deactivate fill glow.

  -- Transition to full only once at least one container item has entered.
  while #world.containerItems(entity.id()) == 0 do
    coroutine.yield()
  end

  containerState:set(containerStates.full)
end

function containerStates.full()
  animator.setAnimationState("glow", "activate")  -- Activate fill glow.

  -- Transition to empty only once no more items are in the container.
  while #world.containerItems(entity.id()) > 0 do
    coroutine.yield()
  end

  containerState:set(containerStates.empty)
end

-- FUNCTIONS

---Adds items near `position` to `trackedItems`.
---@param position Vec2F
function trackItems(position)
  -- Query nearby items
  local queriedItems = world.entityQuery(position, itemDetectRadius, {includedTypes = {"itemdrop"}})

  -- Add queried items to `trackedItems`.
  for _, item in ipairs(queriedItems) do
    table.insert(trackedItems, item)
  end
end

---Attempts to collect all items in `trackedItems`, populating `outCollectedItems` with the list of item IDs that were
---successfully collected.
---
---Note: because it is not mentioned in the documentation, here are two cases where `world.takeItemDrop` is known to
---fail:
---1. the item to take does not exist
---2. the item to take is intangible
---@param outCollectedItems EntityId[]
function collectItems(outCollectedItems)
  local failedItems = {}  -- Table of items that failed to be collected.
  -- For each item in `trackedItems`...
  for _, item in ipairs(trackedItems) do
    -- If `item` exists...
    if world.entityExists(item) then
      -- Attempt to take `item`.
      local itemContents = world.takeItemDrop(item, entity.id())

      -- If successful...
      if itemContents then
        -- Add contents to `takenItems` and item ID to `collectedItems`.
        table.insert(takenItems, itemContents)
        table.insert(outCollectedItems, item)
      else
        -- Add to list of items that failed to be collected.
        table.insert(failedItems, item)
      end
    -- Otherwise, it is dropped.
    end
  end

  trackedItems = failedItems  -- Clear `trackedItems` of everything except the items that failed to be collected.
end

---Refills container contents with as many items from `takenItems` as possible, updating `takenItems`.
function refillContents()
  local newTakenItems = {}

  -- Attempt to refill the container with the current list of taken items.
  for _, item in ipairs(takenItems) do
    local rejectedItem = world.containerAddItems(entity.id(), item)

    if rejectedItem then
      table.insert(newTakenItems, rejectedItem)
    end
  end

  takenItems = newTakenItems
end

function updateOpenState()
  -- If the chest should be opened and was not opened in the previous tick...
  if shouldOpen and not wasOpened then
    animator.setAnimationState("chest", "open")
    wasOpened = true
  -- Otherwise, if the chest should not be opened and was not closed in the previous tick...
  elseif not shouldOpen and wasOpened then
    animator.setAnimationState("chest", "close")
    wasOpened = false
  end
end