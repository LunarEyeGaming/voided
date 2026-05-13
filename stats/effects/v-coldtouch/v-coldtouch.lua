local heatLossRate

function init()
  heatLossRate = config.getParameter("heatLossRate")  -- Rate at which warmth decreases
end

function update(dt)
  if not status.isResource("v-warmth") then
    status.addEphemeralEffect("v-simulatedwarmth")
    world.sendEntityMessage(entity.id(), "v-simulatedwarmth-consume", heatLossRate * dt)
  else
    status.overConsumeResource("v-warmth", heatLossRate * dt)
  end
end