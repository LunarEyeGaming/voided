require "/scripts/vec2.lua"

local beaconDirection
local beaconFlashTime
local arrowRadialOffset
local leftArrowImage
local rightArrowImage

local beaconFlashTimer

function init()
  beaconDirection = animationConfig.animationParameter("beaconDirection")
  beaconFlashTime = animationConfig.animationParameter("beaconFlashTime")
  arrowRadialOffset = animationConfig.animationParameter("arrowRadialOffset")
  leftArrowImage = animationConfig.animationParameter("leftArrowImage")
  rightArrowImage = animationConfig.animationParameter("rightArrowImage")
  flashHighOpacity = animationConfig.animationParameter("flashHighOpacity")
  flashLowOpacity = animationConfig.animationParameter("flashLowOpacity")

  beaconFlashTimer = 0
end

function update()
  local dt = script.updateDt()

  localAnimator.clearDrawables()

  if animationConfig.animationParameter("isActive") and beaconDirection then
    beaconFlashTimer = (beaconFlashTimer + dt) % beaconFlashTime

    drawBeacon()
  end
end

function drawBeacon()
  local beaconFlash = (beaconFlashTimer / beaconFlashTime) < 0.5
  local arrowAngle = vec2.angle(beaconDirection)
  local arrowOffset = vec2.withAngle(arrowAngle, arrowRadialOffset)
  localAnimator.addDrawable({
        image = beaconDirection[1] > 0 and rightArrowImage or leftArrowImage,
        rotation = arrowAngle,
        position = vec2.add(entity.position(), arrowOffset),
        fullbright = true,
        centered = true,
        color = {255, 255, 255, beaconFlash and flashHighOpacity or flashLowOpacity}
      })
end