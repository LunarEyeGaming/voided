require "/scripts/interp.lua"
require "/scripts/util.lua"
require "/scripts/vec2.lua"

--[[
  TODO
]]

local travelTime
local monsterType
local monsterParameters
local releaseStatusEffect

local travelTimer

local initialPosition
local targetPosition

function init()
  travelTime = config.getParameter("travelTime")
  monsterType = config.getParameter("monsterType")
  monsterParameters = config.getParameter("monsterParameters", {})
  releaseStatusEffect = config.getParameter("releaseStatusEffect")

  travelTimer = travelTime

  initialPosition = mcontroller.position()
  targetPosition = config.getParameter("targetPosition")
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

function destroy()
  local entityId = world.spawnMonster(monsterType, mcontroller.position(), monsterParameters)

  if entityId then
    world.callScriptedEntity(entityId, "status.addEphemeralEffect", releaseStatusEffect)
    world.sendEntityMessage(projectile.sourceEntity(), "v-monsterSpawned", entityId)
  else
    sb.logWarn("Monster of type %s with parameters %s failed to spawn", monsterType, monsterParameters)
  end
end
