local poisonRate

local poisonAdderGroup

function init()
  poisonAdderGroup = effect.addStatModifierGroup({{stat = "v-depthPoisonDelta", effectiveMultiplier = 0.0}})
  poisonRate = config.getParameter("poisonRate")  -- Rate at which the depthPoison resource increases
end

function update(dt)
  status.modifyResource("v-depthPoison", poisonRate * dt)
end

-- Removed so that when assets are reloaded, the poison adder groups don't stack.
function uninit()
  effect.removeStatModifierGroup(poisonAdderGroup)
end