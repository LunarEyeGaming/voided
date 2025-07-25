require "/scripts/util.lua"
require "/scripts/vec2.lua"
require "/scripts/rect.lua"
require "/scripts/v-entity.lua"

local spawnRegion
local timeRange
local projectileType
local projectileDirection
local projectileParameters
local projectileBoundBox

local timer

function init()
  spawnRegion = rect.translate(config.getParameter("spawnRegion"), mcontroller.position())
  timeRange = config.getParameter("timeRange")
  projectileType = config.getParameter("projectileType")
  projectileDirection = config.getParameter("projectileDirection")
  projectileParameters = config.getParameter("projectileParameters")
  projectileBoundBox = config.getParameter("projectileCheckRegion")

  monster.setDamageBar("None")
  script.setUpdateDelta(10)

  timer = 0
end

function update(dt)
  timer = timer - dt

  if timer < 0 then
    local pos = rect.randomPoint(spawnRegion)
    local checkRegion = rect.translate(projectileBoundBox, pos)
    local checkCoords = {rect.ll(checkRegion), rect.ur(checkRegion)}

    if not world.rectCollision(checkRegion)
        and #world.entityQuery(checkCoords[1], checkCoords[2], {includedTypes = {"player"}}) == 0 then
      world.spawnProjectile(projectileType, pos, nil, projectileDirection, false, projectileParameters)
      timer = util.randomInRange(timeRange)
    end

    if #world.entityQuery(checkCoords[1], checkCoords[2], {includedTypes = {"player"}}) ~= 0 then
      sb.logInfo("Failed to spawn Ministar cloud due to collision with player.")
    end
  end
end

function shouldDie()
  return false
end