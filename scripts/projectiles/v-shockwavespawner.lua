local oldInit = init or function() end
local oldDestroy = destroy or function() end

local offset
local damageFactor
local monsterType
local monsterParameters

function init()
  oldInit()
  offset = config.getParameter("spawnOffset", {0, 0})
  damageFactor = config.getParameter("shockwaveDamageFactor", 1.0)
  monsterType = config.getParameter("monsterType")
  monsterParameters = config.getParameter("monsterParameters", {})
  monsterParameters.damage = projectile.power() * damageFactor
end

function destroy()
  oldDestroy()
  local ownPos = mcontroller.position()
  world.spawnMonster(monsterType, {ownPos[1] + offset[1], ownPos[2] + offset[2]}, monsterParameters)
end