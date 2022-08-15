require "/scripts/util.lua"
require "/scripts/vec2.lua"

local itemDrop
local itemSpawnPosition

function init()
  itemDrop = config.getParameter("itemDrop", "dirtmaterial")
  itemSpawnPosition = vec2.add(object.position(), config.getParameter("itemSpawnOffset", {0, 0}))
  object.setInteractive(true)
end

function onInteraction(args)
  world.spawnItem(itemDrop, itemSpawnPosition)
  animator.setAnimationState("body", "deactivate")
  object.setInteractive(false)
end