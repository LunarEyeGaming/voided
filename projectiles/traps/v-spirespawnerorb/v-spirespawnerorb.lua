require "/scripts/interp.lua"
require "/scripts/util.lua"
require "/scripts/vec2.lua"


local monsterType
local monsterParameters
local releaseStatusEffect

function init()
  monsterType = config.getParameter("monsterType")
  monsterParameters = config.getParameter("monsterParameters", {})
  releaseStatusEffect = config.getParameter("releaseStatusEffect")
end

function update(dt)
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
