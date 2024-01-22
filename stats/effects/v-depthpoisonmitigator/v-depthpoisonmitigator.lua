local depthPoison

function init()
  depthPoison = status.resource("v-depthPoison")
end

-- Do not allow depth poison to increase
function update(dt)
  depthPoison = math.min(depthPoison, status.resource("v-depthPoison"))
  status.setResource("v-depthPoison", depthPoison)
end