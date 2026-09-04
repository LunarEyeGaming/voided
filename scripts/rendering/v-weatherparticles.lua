require "/scripts/v-animator.lua"

local particleGroupList

local oldInit = init or function() end
local oldUpdate = update or function() end

function init()
  oldInit()

  particleGroupList = {}

  message.setHandler("v-weatherparticles-spawnParticles", function(_, _, particles)
    table.insert(particleGroupList, particles)
  end)
end

function update(dt)
  localAnimator.clearDrawables()

  oldUpdate(dt)

  for i = #particleGroupList, 1, -1 do
    local particleGroup = particleGroupList[i]
    local particle = particleGroup[math.random(1, #particleGroup)]

    vLocalAnimator.spawnOffscreenParticles(particle.particle, {
      density = particle.density,
      exposedOnly = true,
      ignoreWind = particle.ignoreWind,
      autoRotate = particle.autoRotate
    })

    particle.emissionTime = particle.emissionTime - dt
    if particle.emissionTime <= 0 then
      table.remove(particleGroupList, i)
    end
  end
end