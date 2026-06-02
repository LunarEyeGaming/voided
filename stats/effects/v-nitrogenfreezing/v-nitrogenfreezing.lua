local heatLossRate
local damageTickTime

local damageTickTimer

function init()
  animator.setParticleEmitterOffsetRegion("snow", mcontroller.boundBox())
  animator.setParticleEmitterActive("snow", true)

  effect.setParentDirectives(config.getParameter("directives", ""))

  self.movementModifiers = config.getParameter("movementModifiers", {})

  self.healthDamage = config.getParameter("healthDamage", 1)

  damageTickTime = config.getParameter("damageTickTime")

  heatLossRate = config.getParameter("heatLossRate")

  damageTickTimer = damageTickTime
end

function update(dt)
  mcontroller.controlModifiers(self.movementModifiers)

  damageTickTimer = damageTickTimer - dt
  if damageTickTimer <= 0 then
    status.applySelfDamageRequest({
      damageType = "IgnoresDef",
      damage = self.healthDamage,
      damageSourceKind = "ice",
      sourceEntityId = entity.id()
    })
    damageTickTimer = damageTickTime
  end

  if not status.isResource("v-warmth") then
    status.addEphemeralEffect("v-simulatedwarmth")
    world.sendEntityMessage(entity.id(), "v-simulatedwarmth-consume", heatLossRate * dt)
  else
    status.overConsumeResource("v-warmth", heatLossRate * dt)
  end
end

function onExpire()
  -- status.addEphemeralEffect("frostsnare")
end