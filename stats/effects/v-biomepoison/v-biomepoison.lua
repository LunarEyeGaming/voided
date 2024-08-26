local poisonRate

local deltaGroup

function init()
  world.sendEntityMessage(entity.id(), "queueRadioMessage", "v-biomepoison", 5.0)
  poisonRate = config.getParameter("poisonRate")  -- Rate at which the depthPoison resource increases

  deltaGroup = effect.addStatModifierGroup({{stat = "v-depthPoisonDelta", amount = poisonRate}})

  script.setUpdateDelta(0)
end

-- Removed so that when assets are reloaded, the delta groups don't stack.
function uninit()
  effect.removeStatModifierGroup(deltaGroup)
end