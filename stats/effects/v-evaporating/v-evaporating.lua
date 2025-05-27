local tickTime
local tickTimer
local damage
local sunscreenEffect
local sunscreenResistance

function init()
  animator.setParticleEmitterOffsetRegion("flames", mcontroller.boundBox())
  animator.setParticleEmitterActive("flames", true)
  effect.setParentDirectives("fade=FF8800=0.2")

  script.setUpdateDelta(5)

  tickTime = 1.0
  tickTimer = tickTime
  damage = 60
  sunscreenEffect = "v-sunscreen"
  sunscreenResistance = 0.5

  status.applySelfDamageRequest({
      damageType = "IgnoresDef",
      damage = 60,
      damageSourceKind = "fire",
      sourceEntityId = entity.id()
    })
end

function update(dt)
  tickTimer = tickTimer - dt
  if tickTimer <= 0 then
    tickTimer = tickTime
    damage = damage * 2
    local appliedDamage = damage
    if status.uniqueStatusEffectActive(sunscreenEffect) then
      appliedDamage = appliedDamage * (1 - sunscreenResistance)
    end
    status.applySelfDamageRequest({
        damageType = "IgnoresDef",
        damage = appliedDamage,
        damageSourceKind = "fire",
        sourceEntityId = entity.id()
      })
  end
end

function onExpire()
  status.addEphemeralEffect("burning")
end
