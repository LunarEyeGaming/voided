local damage
local launchSpeed
local boltEmitterChoices

function init()
  damage = config.getParameter("damage")
  launchSpeed = config.getParameter("launchSpeed")
  boltEmitterChoices = config.getParameter("boltEmitterChoices")

  status.applySelfDamageRequest({
    damage = damage,
    damageSourceKind = "electric",
    damageType = "IgnoresDef",
    sourceEntityId = entity.id()
  })
  animator.playSound("launch")

  animator.burstParticleEmitter(boltEmitterChoices[math.random(1, #boltEmitterChoices)])
end

function update(dt)
  mcontroller.setYVelocity(launchSpeed)
end