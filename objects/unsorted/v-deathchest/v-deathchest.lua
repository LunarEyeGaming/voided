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

local state

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

  state = FSM:new()
  state:set(states.empty)
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

  -- Filter out items that don't exist.
  trackedItems = util.filter(trackedItems, function(item) return world.entityExists(item) end)

  -- updateAnimation()
  state:update()
end

---Adds items near `position` to `trackedItems`.
---@param position Vec2F
function trackItems(position)
  -- Query nearby items
  local queriedItems = world.entityQuery(position, itemDetectRadius, {includedTypes = {"itemdrop"}})

  -- -- Take each item that was queried and (if successful) add the result and the ID to the takenItems and the
  -- -- trackedItems tables respectively. Also add the ID of the item entity to the list of tracked items.
  -- for _, item in ipairs(queriedItems) do
  --   local itemContents = world.takeItemDrop(item, entity.id())

  --   if itemContents then
  --     table.insert(takenItems, itemContents)
  --     table.insert(trackedItems, item)
  --   end
  -- end
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

-- function updateAnimation()
--   -- Filter out items that don't exist.
--   trackedItems = util.filter(trackedItems, function(item) return world.entityExists(item) end)

--   world.debugText("#trackedItems: %s", #trackedItems, object.position(), "green")
-- end

function uninit()
  object.setConfigParameter("takenItems", takenItems)  -- Store taken items
end

states = {}

function states.empty()
  coroutine.yield()

  sb.logInfo("Is empty")

  -- Update loop.
  while true do
    -- Transition to states.collect when trackedItems is nonempty.
    if #trackedItems > 0 then
      state:set(states.collect)
    end

    -- Transition to states.full when the container has items.
    if #world.containerItems(entity.id()) > 0 then
      state:set(states.full)
    end

    coroutine.yield()
  end
end

function states.collect()
  -- Open chest for collecting.
  sb.logInfo("Opening")

  util.wait(openWaitTime)

  -- Collect items
  for _, item in ipairs(trackedItems) do
    local itemContents = world.takeItemDrop(item, entity.id())
    if itemContents then
      table.insert(takenItems, itemContents)
    else
      sb.logError("Item collection failed.")
    end
  end

  state:set(states.awaitMoreItems)
end

function states.awaitMoreItems()
  util.wait(postCollectWaitTime, function()
    if #trackedItems > 0 then
      state:set(states.collect)
    end
  end)

  -- Close
  sb.logInfo("Closing")

  util.wait(closeWaitTime)

  state:set(states.full)
end

function states.full()
  -- Turn on full light.
  sb.logInfo("Is full")

  -- Update loop.
  while true do
    -- Transition to states.collect when trackedItems is nonempty.
    if #trackedItems > 0 then
      state:set(states.collect)
    end

    -- Transition to states.empty when the container is empty.
    if #world.containerItems(entity.id()) == 0 then
      state:set(states.empty)
    end

    coroutine.yield()
  end
end