require "/scripts/util.lua"
require "/scripts/vec2.lua"

local itemDrop
local itemSpawnPosition

function init()
  if storage.interacted == nil then
    storage.interacted = false
  end

  itemDrop = config.getParameter("itemDrop", "dirtmaterial")
  itemSpawnPosition = vec2.add(object.position(), config.getParameter("itemSpawnOffset", {0, 0}))
  object.setInteractive(not storage.interacted)

  if storage.interacted then
    animator.setAnimationState("body", "deactivate")
  end
end

function onInteraction(args)
  world.spawnItem(itemDrop, itemSpawnPosition)
  animator.setAnimationState("body", "deactivate")
  object.setInteractive(false)
  
  storage.interacted = true
end