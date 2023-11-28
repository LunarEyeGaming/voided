--[[
  Scripts that emits a set of particles on prompt. A script can send in a list of particles to emit as well as an
  emissionId to make the script emit the particle only once.
]]

local oldEmissionId

function update()
  local particles = animationConfig.animationParameter("particles")
  local emissionId = animationConfig.animationParameter("emissionId")
  
  if emissionId ~= oldEmissionId then
    for _, particle in ipairs(particles) do
      localAnimator.spawnParticle(particle)
    end

    oldEmissionId = emissionId
  end
end