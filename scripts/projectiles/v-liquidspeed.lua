require "/scripts/vec2.lua"

local airSpeed
local liquidSpeed
local adjustControlForce
local minLiquidImmersion

local oldInit = init or function() end
local oldUpdate = update or function() end

function init()
  oldInit()

  airSpeed = config.getParameter("speed")
  liquidSpeed = config.getParameter("liquidSpeed")
  adjustControlForce = config.getParameter("adjustControlForce")
  minLiquidImmersion = config.getParameter("minLiquidImmersion", 1.0)
end

function update(dt)
  oldUpdate(dt)

  local velocity = mcontroller.velocity()
  local direction = vec2.norm(velocity)

  local targetSpeed
  if mcontroller.liquidPercentage() >= minLiquidImmersion then
    targetSpeed = liquidSpeed
  else
    targetSpeed = airSpeed
  end

  mcontroller.approachVelocity(vec2.mul(direction, targetSpeed), adjustControlForce)
end