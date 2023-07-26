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
    local pos = world.lineCollision({xPos, ownPos[2]}, testPos)
    
    -- If a collision was detected...
    if pos then
      world.spawnProjectile(projectileType, pos, nil, projectileDirection, false, projectileParameters)
      timer = util.randomInRange(lightningTimeRange)
    end
    
    -- Timer does not get reset until a spot was chosen.
  end
end