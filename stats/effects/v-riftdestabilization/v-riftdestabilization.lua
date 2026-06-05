require "/scripts/rect.lua"
require "/scripts/vec2.lua"
require "/scripts/statuseffects/v-tickdamage.lua"

local destabilizeTime
local destabilizeTickDamage
local nonPlayerMovementModifiers

local timer

function init()
  destabilizeTime = 20

  destabilizeTickDamage = VTickDamage:new{
    kind = "v-void",
    amount = 20,
    interval = 1.0,
    damageType = "IgnoresDef"
  }

  nonPlayerMovementModifiers = config.getParameter("nonPlayerMovementModifiers", {})

  timer = 0
end

function update(dt)
  if entity.entityType() ~= "player" then
    mcontroller.controlModifiers(nonPlayerMovementModifiers)
  end
  timer = math.min(destabilizeTime, timer + dt)

  if timer == destabilizeTime then
    destabilizeTickDamage:update(dt)
  else
    destabilizeTickDamage:reset()
  end

  -- local pos = mcontroller.position()
  -- local newOffset = rect.randomPoint(destabilizeOffsetRegion)
  -- mcontroller.setPosition(vec2.add(vec2.sub(pos, prevOffset), newOffset))
  -- prevOffset = newOffset
end

function uninit()

end
