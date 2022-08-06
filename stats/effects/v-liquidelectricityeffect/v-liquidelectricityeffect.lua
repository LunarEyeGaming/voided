function init()
  animator.setParticleEmitterOffsetRegion("zappies", mcontroller.boundBox())
  animator.setParticleEmitterActive("zappies", true)
  effect.setParentDirectives("fade=8888FF=0.2")

  script.setUpdateDelta(5)

  self.tickTime = 0.25
  self.tickTimer = self.tickTime
  self.damage = 20
end

function update(dt)
  self.tickTimer = self.tickTimer - dt
  if self.tickTimer <= 0 then
    self.tickTimer = self.tickTime
    status.applySelfDamageRequest({
        damageType = "IgnoresDef",
        damage = self.damage,
        damageSourceKind = "electric",
        sourceEntityId = entity.id()
      })
  end
end

function onExpire()
  status.addEphemeralEffect("electrified")
end
