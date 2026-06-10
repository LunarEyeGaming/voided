require "/scripts/rect.lua"
require "/scripts/vec2.lua"
require "/scripts/statuseffects/v-tickdamage.lua"

local destabilizeTime
local destabilizeTickDamage

local timer

function init()
  if entity.entityType() == "player" then
    destabilizeTime = 20
  else
    destabilizeTime = 10
  end

  destabilizeTickDamage = VTickDamage:new{
    kind = "v-void",
    amount = 20,
    interval = 1.0,
    damageType = "IgnoresDef"
  }

  timer = 0
end

function update(dt)
  timer = math.min(destabilizeTime, timer + dt)

  if timer == destabilizeTime then
    destabilizeTickDamage:update(dt)
  else
    destabilizeTickDamage:reset()
  end
end

function uninit()

end
