require "/scripts/util.lua"
require "/scripts/vec2.lua"

local lightningXPosRange
local lightningTimeRange
local maxSpawnHeight
local projectileType
local projectileDirection
local projectileParameters

local timer

function init()
  lightningXPosRange = config.getParameter("lightningXPosRange")
  lightningTimeRange = config.getParameter("lightningTimeRange")
  maxSpawnHeight = config.getParameter("maxSpawnHeight")
  projectileType = config.getParameter("projectileType")
  projectileDirection = config.getParameter("projectileDirection")
  projectileParameters = config.getParameter("projectileParameters")

  timer = util.randomInRange(lightningTimeRange)
end

function update(dt)
  local ownPos = stagehand.position()

  timer = timer - dt

  if timer < 0 then
    local xPos = util.randomInRange(lightningXPosRange) + ownPos[1]
    local testPos = vec2.add({xPos, ownPos[2]}, {0, maxSpawnHeight})

    world.spawnProjectile(projectileType, testPos, nil, projectileDirection, false, projectileParameters)
    timer = util.randomInRange(lightningTimeRange)
    
    -- Timer does not get reset until a spot was chosen.
  end
end