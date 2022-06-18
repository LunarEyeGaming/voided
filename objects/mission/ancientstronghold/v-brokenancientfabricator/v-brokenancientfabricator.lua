require "/scripts/util.lua"
require "/scripts/vec2.lua"

function init()
  self.itemDrop = config.getParameter("itemDrop", "dirtmaterial")
  self.itemSpawnOffset = config.getParameter("itemSpawnOffset", {0, 0})
  self.itemSpawnPosition = vec2.add(object.position(), self.itemSpawnOffset)
  object.setInteractive(true)
end

function onInteraction(args)
  world.spawnItem(self.itemDrop, self.itemSpawnPosition)
  animator.setAnimationState("body", "deactivate")
  object.setInteractive(false)
end