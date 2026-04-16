local heatLossRate

function init()
  heatLossRate = config.getParameter("heatLossRate")  -- Rate at which warmth decreases
end

function update(dt)
  status.overConsumeResource("v-warmth", heatLossRate * dt)
end