require "/scripts/vec2.lua"

local disappearTime
local projectileParameters

local shouldDieVar

function init()
  disappearTime = config.getParameter("disappearTime")
  projectileParameters = config.getParameter("projectileParameters")

  monster.setDeathSound("deathPuff")
end

function update(dt)
  if disappearTime and world.time() > disappearTime then
    monster.setDropPool(nil)
    shouldDieVar = true
  end

  if status.resource("health") <= 0.0 then
    shouldDieVar = true
  end
end

function shouldDie()
  return shouldDieVar
end

function die()
  world.spawnProjectile("v-proxyprojectile", mcontroller.position(), entity.id(), {0, 0}, false, projectileParameters)
end

function uninit()
  if not shouldDieVar then
    world.sendEntityMessage("v-riftzonemanager-stagehand", "pushRiftRemnant", {
      position = mcontroller.position(),
      disappearTime = disappearTime
    })
  end
end