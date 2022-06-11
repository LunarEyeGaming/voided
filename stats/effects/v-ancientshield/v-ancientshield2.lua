function init()
  animator.setAnimationState("shield", "appear")
  effect.addStatModifierGroup({{stat = "invulnerable", amount = 1}})

  script.setUpdateDelta(0)
end

function onExpire()
  status.addEphemeralEffect("v-ancientshielddisappear")
end