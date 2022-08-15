local tickTime
local tickTimer
local tickDamage

function init()
  animator.setParticleEmitterOffsetRegion("zappies", mcontroller.boundBox())
  animator.setParticleEmitterActive("zappies", true)
  effect.setParentDirectives("fade=8888FF=0.2")

  script.setUpdateDelta(5)

  tickTime = 0.25
  tickTimer = tickTime
  tickDamage = 20
end

function update(dt)
  tickTimer = tickTimer - dt
  if tickTimer <= 0 then
    tickTimer = tickTime
    status.applySelfDamageRequest({
        damageType = "IgnoresDef",
        damage = tickDamage,
        damageSourceKind = "electric",
        sourceEntityId = entity.id()
      })
  end
end

function onExpire()
  status.addEphemeralEffect("electrified")
end
