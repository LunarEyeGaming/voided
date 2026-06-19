require "/scripts/v-util.lua"

function init()
  message.setHandler("v-healingcooldown-enforce", function(_, _, detectStatusEffect, cooldownStatusEffect, cooldownPath)
    local defaults = root.assetJson("/v-defaultsettings.config:mechanics")
    local settings = player.getProperty("v-healingCooldownSettings", defaults)
    local cooldown = settings[cooldownPath]

    if vUtil.hasStatusEffect(detectStatusEffect) then
      status.addEphemeralEffect(cooldownStatusEffect, cooldown)
    end
  end)
end