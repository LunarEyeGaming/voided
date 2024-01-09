require "/scripts/util.lua"
require "/scripts/vec2.lua"
require "/scripts/rect.lua"

local bubbleOffsetRegion
local bubbleTimeRange
local maxSpawnHeight
local projectileType
local projectileDirection
local projectileParameters

local timer

function init()
  bubbleOffsetRegion = config.getParameter("bubbleOffsetRegion")
  bubbleTimeRange = config.getParameter("bubbleTimeRange")
  maxSpawnHeight = config.getParameter("maxSpawnHeight")
  projectileType = config.getParameter("projectileType")
  projectileDirection = config.getParameter("projectileDirection")
  projectileParameters = config.getParameter("projectileParameters")

  timer = util.randomInRange(bubbleTimeRange)
end

function update(dt)
  local ownPos = stagehand.position()

  timer = timer - dt

  if timer < 0 then
    local projectilePos = vec2.add(ownPos, rect.randomPoint(bubbleOffsetRegion))

    -- No material in the background and a liquid at the spawn position implies ocean
    if world.material(projectilePos, "background") == false and world.liquidAt(projectilePos) then
      world.spawnProjectile(projectileType, projectilePos, nil, projectileDirection, false, projectileParameters)
      timer = util.randomInRange(bubbleTimeRange)
    end
    
    -- Timer does not get reset until a spot was chosen.
  end
end