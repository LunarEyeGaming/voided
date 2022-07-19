local oldInit = init or function() end
local oldDestroy = destroy or function() end

function init()
  oldInit()
  self.offset = config.getParameter("spawnOffset", {0, 0})
  self.damageFactor = config.getParameter("shockwaveDamageFactor", 1.0)
  self.monsterType = config.getParameter("monsterType")
  self.monsterParameters = config.getParameter("monsterParameters", {})
  self.monsterParameters.damage = projectile.power() * self.damageFactor
end

function destroy()
  oldDestroy()
  local ownPos = mcontroller.position()
  world.spawnMonster(self.monsterType, {ownPos[1] + self.offset[1], ownPos[2] + self.offset[2]}, self.monsterParameters)
end