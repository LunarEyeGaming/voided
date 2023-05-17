local oldInit = init or function() end
local oldDestroy = destroy or function() end

local offset
local shockwaveDamageFactor
local monsterType
local monsterParameters

function init()
  oldInit()
  offset = config.getParameter("spawnOffset", {0, 0})
  shockwaveDamageFactor = config.getParameter("shockwaveDamageFactor", 1.0)
  monsterType = config.getParameter("monsterType")
  monsterParameters = getMonsterParameters(shockwaveDamageFactor)
end

function destroy()
  oldDestroy()
  local ownPos = mcontroller.position()
  world.spawnMonster(monsterType, {ownPos[1] + offset[1], ownPos[2] + offset[2]}, monsterParameters)
end

function getMonsterParameters(damageFactor)
  local params = config.getParameter("monsterParameters", {})
  params.damage = (params.damage or (projectile.power() * damageFactor)) * projectile.powerMultiplier()
  params.damageTeamType = params.damageTeamType or entity.damageTeam().type
  params.damageTeam = params.damageTeam or entity.damageTeam().team
  params.sourceEntity = projectile.sourceEntity()
  
  return params
end