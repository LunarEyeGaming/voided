local depthPoisonDelta

local deltaGroup

function init()
  depthPoisonDelta = config.getParameter("depthPoisonDelta")

  deltaGroup = effect.addStatModifierGroup({{stat = "v-depthPoisonDelta", amount = depthPoisonDelta}})

  script.setUpdateDelta(0)
end

-- Removed so that when assets are reloaded, the delta groups don't stack.
function uninit()
  effect.removeStatModifierGroup(deltaGroup)
end