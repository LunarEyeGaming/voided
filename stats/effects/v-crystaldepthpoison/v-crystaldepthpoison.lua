local poisonRate

function init()
  poisonRate = config.getParameter("poisonRate")  -- Rate at which the depthPoison resource increases
end

function update(dt)
  status.modifyResource("v-depthPoison", poisonRate * dt)
end