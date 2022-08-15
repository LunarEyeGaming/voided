require "/scripts/voidedutil.lua"

local healingRate

function init()
  animator.setParticleEmitterOffsetRegion("healing", mcontroller.boundBox())
  animator.setParticleEmitterEmissionRate("healing", config.getParameter("emissionRate", 3))
  animator.setParticleEmitterActive("healing", true)

  script.setUpdateDelta(5)

  healingRate = config.getParameter("healAmount", 30) / effect.duration()
end

function update(dt)
  status.modifyResource("health", healingRate * dt)
end

function onExpire()

end

function uninit()
  if hasStatusEffect("v-quickhealnerf") then
    status.addEphemeralEffect("v-slowhealblock")
  end
end
