local keyItems
local deleteItem

function init()
  keyItems = config.getParameter("acceptedItems")
  deleteItem = config.getParameter("deleteItem")

  if storage.state == nil then
    output(config.getParameter("defaultSwitchState", false))
  else
    output(storage.state)
  end
  
  -- Retain state if unloaded
  animator.setAnimationState("socket", storage.state and "active" or "inactive")
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
      animator.setAnimationState("socket", "deactivating")
      animator.playSound("deactivate")
    else
      -- Activating
      animator.setAnimationState("socket", "activating")
      animator.playSound("activate")
    end
  end

  storage.state = state

  if state then
    object.setAllOutputNodes(true)
  else
    object.setAllOutputNodes(false)
  end
end
