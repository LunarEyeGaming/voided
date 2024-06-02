local keyItems
local deleteItem

local unlockStateType

local unlockingState
local lockingState
local unlockedState
local lockedState

local unlockSound
local lockSound

function init()
  keyItems = config.getParameter("acceptedItems")
  deleteItem = config.getParameter("deleteItem")
  
  unlockStateType = config.getParameter("unlockStateType", "unlockState")

  unlockingState = config.getParameter("unlockingState", "unlocking")
  lockingState = config.getParameter("lockingState", "locking")
  unlockedState = config.getParameter("unlockedState", "unlocked")
  lockedState = config.getParameter("lockedState", "locked")
  
  unlockSound = config.getParameter("unlockSound", "unlock")
  lockSound = config.getParameter("lockSound", "lock")

  if storage.state == nil then
    output(config.getParameter("defaultSwitchState", false))
  else
    output(storage.state)
  end
  
  -- Retain state if unloaded
  animator.setAnimationState(unlockStateType, storage.state and unlockedState or lockedState)
end

function update(dt)
  local items = world.containerItems(entity.id())
  local acceptedItems = getMatchingItems(items, keyItems)

  if next(acceptedItems) ~= nil then
    output(true)

    if deleteItem then
      deleteItems(acceptedItems)
    end
  elseif not deleteItem then
    output(false)
  end
end

function getMatchingItems(items, keyItems)
  matchedItems = {}

  for _, item in pairs(items) do
    if matchItem(item, keyItems) then
      table.insert(matchedItems, item)
    end
  end

  return matchedItems
end

function matchItem(item, keyItems)
  for _, keyItem in pairs(keyItems) do
    if item.name == keyItem then
      return true
    end
  end

  return false
end

function deleteItems(items)
  for _, item in pairs(items) do
    world.containerConsume(entity.id(), item)
  end
end

function output(state)
  if storage.state ~= state then
    -- Deactivating
    if storage.state then
      animator.setAnimationState(unlockStateType, lockingState)
      animator.playSound(lockSound)
    else
      -- Activating
      animator.setAnimationState(unlockStateType, unlockingState)
      animator.playSound(unlockSound)
    end
  end

  storage.state = state

  if state then
    object.setAllOutputNodes(true)
  else
    object.setAllOutputNodes(false)
  end
end
