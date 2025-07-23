require "/scripts/v-util.lua"

function init()
  message.setHandler("v-healingcooldown-enforce", function(_, _, detectStatusEffect, cooldownStatusEffect, cooldownPath)
    local defaults = root.assetJson("/v-healingcooldowndefaults.config")
    local settings = player.getProperty("v-healingCooldownSettings", defaults)
    local cooldown = settings[cooldownPath]

    if vUtil.hasStatusEffect(detectStatusEffect) then
      status.addEphemeralEffect(cooldownStatusEffect, cooldown)
    end
  end)
end