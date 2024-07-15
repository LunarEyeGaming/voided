require "/objects/wired/light/light.lua"

local oldInit = init or function() end
local oldSetLightState = setLightState or function() end

local targetId
local pointDirection

function init()
  oldInit()

  passParamToAnim("beaconFlashTime")
  passParamToAnim("arrowRadialOffset")
  passParamToAnim("leftArrowImage")
  passParamToAnim("rightArrowImage")
  passParamToAnim("flashHighOpacity")
  passParamToAnim("flashLowOpacity")

  targetId = world.loadUniqueEntity(config.getParameter("beaconUniqueId", "v-voltagecitybeacon"))
  if targetId ~= 0 then
    pointDirection = world.distance(world.entityPosition(targetId), object.position())
    object.setAnimationParameter("beaconDirection", pointDirection)
  end
end

function setLightState(newState)
  oldSetLightState(newState)
  
  object.setAnimationParameter("isActive", storage.state)
end

function passParamToAnim(param, default)
  object.setAnimationParameter(param, config.getParameter(param, default))
end