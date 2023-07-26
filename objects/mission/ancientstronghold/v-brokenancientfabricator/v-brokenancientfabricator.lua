require "/scripts/util.lua"
require "/scripts/vec2.lua"

local itemDrop
local itemSpawnPosition

function init()
  if not storage.interacted then
    storage.interacted = false
  end

  itemDrop = config.getParameter("itemDrop", "dirtmaterial")
  itemSpawnPosition = vec2.add(object.position(), config.getParameter("itemSpawnOffset", {0, 0}))
  object.setInteractive(not storage.interacted)
end

function onInteraction(args)
  world.spawnItem(itemDrop, itemSpawnPosition)
  animator.setAnimationState("body", "deactivate")
  object.setInteractive(false)
  
  storage.interacted = true
end