require "/scripts/v-animator.lua"

local oldInit = init or function() end

function init()
  oldInit()

  message.setHandler("v-weatherparticles-spawnParticle", function(_, _, particle, density, ignoreWind)
    vLocalAnimator.spawnOffscreenParticles(particle, {
      density = density,
      exposedOnly = true,
      ignoreWind = ignoreWind
    })
  end)
end