function init()
  world.sendEntityMessage(entity.id(), "queueRadioMessage", "v-biomeelectric", 5.0)
  effect.addStatModifierGroup({{stat = "electricResistance", amount = -0.5}})

  animator.setParticleEmitterOffsetRegion("sparks", mcontroller.boundBox())
  animator.setParticleEmitterActive("sparks", true)

  script.setUpdateDelta(0)
end

function update(dt)

end

function uninit()
  
end
