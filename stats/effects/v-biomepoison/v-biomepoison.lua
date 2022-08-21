local poisonRate

function init()
  world.sendEntityMessage(entity.id(), "queueRadioMessage", "v-biomepoison", 5.0)
  poisonRate = config.getParameter("poisonRate")  -- Rate at which the depthPoison resource increases
end

function update(dt)
  status.modifyResource("v-depthPoison", poisonRate * dt)
end