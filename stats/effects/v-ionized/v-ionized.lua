local tickTime
local tickTimer
local tickDamage

function init()
  animator.setParticleEmitterOffsetRegion("flames", mcontroller.boundBox())
  animator.setParticleEmitterActive("flames", true)
  effect.setParentDirectives("fade=9bba3d=0.2")

  script.setUpdateDelta(5)

  tickTime = 0.5
  tickTimer = tickTime
  tickDamage = 10

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
    tickDamage = tickDamage + 8
    status.applySelfDamageRequest({
        damageType = "IgnoresDef",
        damage = tickDamage,
        damageSourceKind = "poisonplasma",
        sourceEntityId = entity.id()
      })
  end
end
