require "/scripts/vec2.lua"

local target
local orbitRadius
local orbitPeriod
local shieldStatusEffect
local timer

function init()
  monster.setDeathParticleBurst("deathPoof")
  animator.setAnimationState("movement", "idle")

  if animator.hasSound("deathPuff") then
    monster.setDeathSound("deathPuff")
  end

  message.setHandler("despawn", despawn)
  
  target = config.getParameter("target")
  orbitRadius = config.getParameter("orbitRadius", 2)
  orbitPeriod = config.getParameter("orbitPeriod", 1.5)
  shieldStatusEffect = config.getParameter("shieldStatusEffect", "v-ancientshield")
  timer = 0
end

function shouldDie()
  return not status.resourcePositive("health")
end

function update(dt)
  if not target or not world.entityExists(target) then
    status.setResourcePercentage("health", 0)
    return
  end
  timer = timer + dt
  mcontroller.setPosition(
    vec2.add(
      world.entityPosition(target),
      {
        orbitRadius * math.cos(2 * math.pi * timer / orbitPeriod),
        orbitRadius * math.sin(2 * math.pi * timer / orbitPeriod)
      }
    )
  )
  world.sendEntityMessage(target, "applyStatusEffect", shieldStatusEffect)
end

function despawn()
  monster.setDropPool(nil)
  monster.setDeathParticleBurst(nil)
  monster.setDeathSound(nil)
  status.addEphemeralEffect("monsterdespawn")
end