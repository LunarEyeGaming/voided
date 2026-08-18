require "/scripts/vec2.lua"

local disappearTime

function init()
  disappearTime = config.getParameter("disappearTime")

  monster.setDeathSound("deathPuff")
  monster.setDeathParticleBurst("deathPoof")
end

function update(dt)
  if world.isTileProtected(mcontroller.position()) then
    monster.setDropPool(nil)
    g_shouldDieVar = true
  end

  if disappearTime and world.time() > disappearTime then
    monster.setDropPool(nil)
    g_shouldDieVar = true
  end

  if status.resource("health") <= 0.0 then
    g_shouldDieVar = true
  end
end

function shouldDie()
  return g_shouldDieVar
end

function die()
end

function uninit()
  if not g_shouldDieVar then
    world.sendEntityMessage("v-riftzonemanager-stagehand", "pushRiftRemnant", {
      position = mcontroller.position(),
      disappearTime = disappearTime
    })
  end
end