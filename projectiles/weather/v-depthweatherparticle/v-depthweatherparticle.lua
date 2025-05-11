local messageRange
local particle
local density
local minDepth
local maxDepth
local ignoreWind

function init()
  messageRange = config.getParameter("messageRange")
  particle = config.getParameter("particle")
  density = config.getParameter("density")
  minDepth = config.getParameter("depthRange.0")
  maxDepth = config.getParameter("depthRange.1")
  ignoreWind = config.getParameter("particle.ignoreWind")
end

function destroy()
  local queried = world.entityQuery(mcontroller.position(), messageRange, {includedTypes = {"player"}})
  for _, entityId in ipairs(queried) do
    world.sendEntityMessage(entityId, "v-ministareffects-spawnWeatherParticle", particle, density, minDepth, maxDepth, ignoreWind)
  end
end