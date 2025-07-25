require "/scripts/util.lua"
require "/scripts/vec2.lua"
require "/scripts/rect.lua"

local spawnRegion
local timeRange
local projectileType
local projectileDirection
local projectileParameters
local projectileBoundBox

local timer

function init()
  spawnRegion = rect.translate(config.getParameter("spawnRegion"), stagehand.position())
  timeRange = config.getParameter("timeRange")
  projectileType = config.getParameter("projectileType")
  projectileDirection = config.getParameter("projectileDirection")
  projectileParameters = config.getParameter("projectileParameters")
  projectileBoundBox = config.getParameter("projectileCheckRegion")

  timer = 0
end

function update(dt)
  timer = timer - dt

  if timer < 0 then
    local pos = rect.randomPoint(spawnRegion)

    if not world.rectCollision(rect.translate(projectileBoundBox, pos)) then
      world.spawnProjectile(projectileType, pos, nil, projectileDirection, false, projectileParameters)
      timer = util.randomInRange(timeRange)
    end
  end
end