require "/scripts/vec2.lua"

function init()
  monster.setDeathParticleBurst("deathPoof")
  animator.setAnimationState("movement", "idle")

  if animator.hasSound("deathPuff") then
    monster.setDeathSound("deathPuff")
  end

  message.setHandler("despawn", despawn)
  
  self.target = config.getParameter("target")
  self.orbitRadius = config.getParameter("orbitRadius", 2)
  self.orbitPeriod = config.getParameter("orbitPeriod", 1.5)
  self.shieldStatusEffect = config.getParameter("shieldStatusEffect", "v-ancientshield")
  self.timer = 0
end

function shouldDie()
  return not status.resourcePositive("health")
end

function update(dt)
  if not self.target or not world.entityExists(self.target) then
    status.setResourcePercentage("health", 0)
    return
  end
  self.timer = self.timer + dt
  mcontroller.setPosition(
    vec2.add(
      world.entityPosition(self.target),
      {
        self.orbitRadius * math.cos(2 * math.pi * self.timer / self.orbitPeriod),
        self.orbitRadius * math.sin(2 * math.pi * self.timer / self.orbitPeriod)
      }
    )
  )
  world.sendEntityMessage(self.target, "applyStatusEffect", self.shieldStatusEffect)
end

function despawn()
  monster.setDropPool(nil)
  monster.setDeathParticleBurst(nil)
  monster.setDeathSound(nil)
  status.addEphemeralEffect("monsterdespawn")
end