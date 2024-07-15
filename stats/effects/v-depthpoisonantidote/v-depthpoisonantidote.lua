function init()
  if status.isResource("v-depthPoison") then
    status.modifyResource("v-depthPoison", -config.getParameter("decreaseAmount"))
  end
end