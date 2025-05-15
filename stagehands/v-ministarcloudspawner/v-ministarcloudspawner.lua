require "/scripts/util.lua"
require "/scripts/vec2.lua"
require "/scripts/rect.lua"

local xPosRange
local timeRange
local spawnHeight
local projectileType
local projectileDirection
local projectileParameters
local projectileBoundBox
local liquidId

local timer

function init()
  xPosRange = config.getParameter("xPosRange")
  timeRange = config.getParameter("timeRange")
  spawnHeight = config.getParameter("spawnHeight")
  projectileType = config.getParameter("projectileType")
  projectileDirection = config.getParameter("projectileDirection")
  projectileParameters = config.getParameter("projectileParameters")
  projectileBoundBox = config.getParameter("projectileCheckRegion")
  liquidId = config.getParameter("liquidId")

  timer = util.randomInRange(timeRange)
end

function update(dt)
  local ownPos = stagehand.position()

  timer = timer - dt

  if timer < 0 then
    local xPos = util.randomInRange(xPosRange) + ownPos[1]

    local pos = {xPos, ownPos[2] + spawnHeight}

    if not world.rectCollision(rect.translate(projectileBoundBox, pos)) then
      local liquid = world.liquidAt(pos)

      if liquid and liquid[1] == liquidId then
        world.spawnProjectile(projectileType, pos, nil, projectileDirection, false, projectileParameters)
        timer = util.randomInRange(timeRange)
      end
    end
  end
end