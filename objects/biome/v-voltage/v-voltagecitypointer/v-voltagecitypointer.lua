local targetId
local pointDirection

function init()
  passParamToAnim("beaconFlashTime")
  passParamToAnim("arrowRadialOffset")
  passParamToAnim("leftArrowImage")
  passParamToAnim("rightArrowImage")
  passParamToAnim("flashHighOpacity")
  passParamToAnim("flashLowOpacity")

  targetId = world.loadUniqueEntity("v-voltagecitybeacon")
  if targetId ~= 0 then
    pointDirection = world.distance(world.entityPosition(targetId), object.position())
    object.setAnimationParameter("beaconDirection", pointDirection)
  end
end

function update(dt)
end

function passParamToAnim(param, default)
  object.setAnimationParameter(param, config.getParameter(param, default))
end