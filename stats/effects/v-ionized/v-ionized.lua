local tickTime
local tickTimer
local tickDamage
local compoundingTickDamage

function init()
  animator.setParticleEmitterOffsetRegion("flames", mcontroller.boundBox())
  animator.setParticleEmitterActive("flames", true)
  effect.setParentDirectives("fade=9bba3d=0.2")

  script.setUpdateDelta(5)

  tickTime = config.getParameter("tickTime")
  tickDamage = config.getParameter("tickDamage")
  compoundingTickDamage = config.getParameter("compoundingTickDamage")
  tickTimer = tickTime

  status.applySelfDamageRequest({
      damageType = "IgnoresDef",
      damage = tickDamage,
      damageSourceKind = "poisonplasma",
      sourceEntityId = entity.id()
    })
end

function update(dt)
  tickTimer = tickTimer - dt
  if tickTimer <= 0 then
    tickTimer = tickTime
    tickDamage = tickDamage + compoundingTickDamage
    status.applySelfDamageRequest({
        damageType = "IgnoresDef",
        damage = tickDamage,
        damageSourceKind = "poisonplasma",
        sourceEntityId = entity.id()
      })
  end
end
