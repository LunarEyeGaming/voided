function init()
  animator.setParticleEmitterOffsetRegion("drips", mcontroller.boundBox())
  animator.setParticleEmitterActive("drips", true)
  effect.setParentDirectives("fade=300030=0.8")
  effect.addStatModifierGroup({
    {stat = "fireResistance", amount = -0.5}
  })

  script.setUpdateDelta(0)
end