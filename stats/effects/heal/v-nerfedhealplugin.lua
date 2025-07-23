local oldUninit = uninit

function uninit()
  if oldUninit then
    oldUninit()
  end

  local detectStatusEffect = config.getParameter("v-detectStatusEffect")  -- Status effect to check for
  local cooldownStatusEffect = config.getParameter("v-cooldownStatusEffect")  -- Status effect to apply after healing
  local cooldownPath = config.getParameter("v-cooldownPath")  -- Location of default cooldown

  -- In case something goes wrong.
  if not detectStatusEffect then
    sb.logWarn("Parameter 'v-detectStatusEffect' not defined")
    return
  end

  if not cooldownStatusEffect then
    sb.logWarn("Parameter 'v-cooldownStatusEffect' not defined")
    return
  end

  if not cooldownPath then
    sb.logWarn("Parameter 'v-cooldownPath' not defined")
    return
  end

  world.sendEntityMessage(entity.id(), "v-healingcooldown-enforce", detectStatusEffect, cooldownStatusEffect, cooldownPath)
end
