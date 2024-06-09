require "/scripts/interp.lua"
require "/scripts/util.lua"
require "/scripts/vec2.lua"

--[[
  TODO
]]

local travelTime

local travelTimer

local initialPosition
local targetPosition

function init()
  travelTime = config.getParameter("travelTime")

  travelTimer = travelTime

  initialPosition = mcontroller.position()
  -- Stop the projectile from zooping across the world if the world border is between the initial and target positions.
  targetPosition = world.nearestTo(initialPosition, config.getParameter("targetPosition"))
end

function update(dt)
  if not targetPosition then
    return
  end

  travelTimer = math.max(0, travelTimer - dt)
  local ratio = 1 - (travelTimer / travelTime)

  mcontroller.setPosition(
    {
      interp.sin(ratio, initialPosition[1], targetPosition[1]),
      interp.sin(ratio, initialPosition[2], targetPosition[2])
    }
  )
end
