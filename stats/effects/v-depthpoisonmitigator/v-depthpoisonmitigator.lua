local depthPoison

function init()
  depthPoison = status.resource("v-depthPoison")
end

function update(dt)
  status.setResource("v-depthPoison", depthPoison)
end