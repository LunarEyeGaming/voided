local poisonAdderGroup

function init()
  world.sendEntityMessage(entity.id(), "queueRadioMessage", "v-biomepoison", 5.0)
  poisonAdderGroup = effect.addStatModifierGroup({{stat = "v-depthPoisonDelta", effectiveMultiplier = 0.25}})
end

function update(dt)
end

-- Removed so that when assets are reloaded, the poison adder groups don't stack.
function uninit()
  effect.removeStatModifierGroup(poisonAdderGroup)
end