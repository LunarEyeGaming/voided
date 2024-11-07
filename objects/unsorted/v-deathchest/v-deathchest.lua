require "/scripts/util.lua"

local playerDetectRadius
local itemDetectRadius
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

  message.setHandler("open", function()
    shouldOpen = true  -- Make the updateOpenState() function open the chest in the next tick.
  end)

  message.setHandler("close", function()
    shouldOpen = false  -- Make the updateOpenState() function close the chest in the next tick.
  end)
end

function update(dt)
  prevAlivePlayers = alivePlayers
  alivePlayers = world.entityQuery(object.position(), playerDetectRadius, {includedTypes = {"player"}})

  -- Check for players that have died or stopped existing between the previous update and this update. For each of those
  -- players, collect the nearby items.
  for _, playerId in ipairs(prevAlivePlayers) do
    -- If the player is no longer in alivePlayers because they stopped existing...
    if not contains(alivePlayers, playerId) and not world.entityExists(playerId) then
      sb.logInfo("%s has stopped existing. Position: %s", playerId, playerPositionMap[playerId])

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

  -- Collect items
  for _, item in ipairs(trackedItems) do
    local itemContents = world.takeItemDrop(item, entity.id())
    if itemContents then
      table.insert(takenItems, itemContents)
      table.insert(collectedItems, item)
    else
      sb.logError("Item collection failed.")
    end
  end

  trackedItems = {}  -- Clear tracked items

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