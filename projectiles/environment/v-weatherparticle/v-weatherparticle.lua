local messageRange
local weatherParticles

function init()
  messageRange = config.getParameter("weatherParticleMessageRange")
  weatherParticles = config.getParameter("weatherParticles", {})
end

function destroy()
  local queried = world.entityQuery(mcontroller.position(), messageRange, {includedTypes = {"player"}})
  for _, entityId in ipairs(queried) do
    world.sendEntityMessage(entityId, "v-weatherparticles-spawnParticles", weatherParticles)
  end
end