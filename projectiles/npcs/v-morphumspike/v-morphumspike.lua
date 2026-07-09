require "/scripts/vec2.lua"

function destroy()
  local sourceId = projectile.sourceEntity()
  if not sourceId or not world.entityExists(sourceId) then
    return
  end

  local aimVector = vec2.withAngle(mcontroller.rotation())
  local offset = config.getParameter("monster.offset", {0, 0})
  local rotatedOffset = config.getParameter("monster.rotatedOffset", {0, 0})
  local monsterType = config.getParameter("monster.type")

  local level = world.callScriptedEntity(sourceId, "monster.level")
  local monsterParams = world.callScriptedEntity(sourceId, "monster.uniqueParameters")
  local params = {
    level = level,
    aimVector = aimVector,
    masterId = sourceId
  }
  params = sb.jsonMerge(monsterParams, params)
  world.spawnMonster(monsterType, vec2.add(mcontroller.position(), vec2.add(offset, vec2.rotate(rotatedOffset, mcontroller.rotation()))), params)
end