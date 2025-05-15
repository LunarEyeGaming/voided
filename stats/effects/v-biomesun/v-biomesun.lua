require "/scripts/statuseffects/v-tickdamage.lua"

local tickDamage

function init()
  world.sendEntityMessage(entity.id(), "queueRadioMessage", "v-biomesun", 5.0)

  script.setUpdateDelta(6)

  tickDamage = VTickDamage:new{ kind = "fire", amount = 15, interval = 10, damageType = "IgnoresDef" }
end

function update(dt)
  tickDamage:update(dt)
end