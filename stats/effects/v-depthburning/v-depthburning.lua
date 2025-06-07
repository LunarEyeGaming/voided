require "/scripts/interp.lua"
require "/scripts/statuseffects/v-tickdamage.lua"

local minDepth
local maxDepth
local minDamage
local maxDamage

function init()
  minDepth = 1000  -- The depth at which the player takes the most burn damage.

  maxDepth = 1500  -- Depth at which the player starts burning
  minDamage = 1
  maxDamage = 20
  tickTime = 0.3

  tickDamage = VTickDamage:new{ kind = "fire", amount = minDamage, damageType = "IgnoresDef", interval = tickTime, source = entity.id() }

  if mcontroller.position()[2] > maxDepth then
    effect.expire()
  end
end

function update(dt)
  local pos = mcontroller.position()
  -- If the player should be burned...
  if pos[2] <= maxDepth then
    local damage = interp.linear((pos[2] - minDepth) / (maxDepth - minDepth), maxDamage, minDamage)
    -- Update damage amount. It is a linear interpolation between maxDamage and minDamage, where damage grows as depth
    -- (aka y position) decreases.
    tickDamage.damageRequest.damage = damage * (1 - status.stat("v-ministarHeatResistance"))
    tickDamage:update(dt)  -- Run the tickDamage object for one tick.
  else
    effect.expire()
  end
end