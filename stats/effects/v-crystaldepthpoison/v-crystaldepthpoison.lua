local poisonRate

function init()
  poisonRate = config.getParameter("poisonRate")  -- Rate at which the depthPoison resource increases

  if not status.isResource("v-depthPoison") then
    script.setUpdateDelta(0)
  end
end

function update(dt)
  status.modifyResource("v-depthPoison", poisonRate * dt)
end