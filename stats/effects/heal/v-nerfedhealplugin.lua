require "/scripts/v-util.lua"

local oldUninit = uninit

function uninit()
  if oldUninit then
    oldUninit()
  end

  local detectStatusEffect = config.getParameter("v-detectStatusEffect")  -- Status effect to check for
  local cooldownStatusEffect = config.getParameter("v-cooldownStatusEffect")  -- Status effect to apply after healing

  -- In case something goes wrong.
  if not detectStatusEffect then
    sb.logWarn("Parameter 'v-detectStatusEffect' not defined")
    return
  end

  if not cooldownStatusEffect then
    sb.logWarn("Parameter 'v-cooldownStatusEffect' not defined")
  end

  if voidedUtil.hasStatusEffect(detectStatusEffect) then
    status.addEphemeralEffect(cooldownStatusEffect)
  end
end
