require "/scripts/vec2.lua"
require "/scripts/util.lua"
require "/scripts/voidedutil.lua"

local baseLayerImage
local fillLayerImage
local flashLayerImage
local warningLayerImage

local poisonRatio
local flashTime
local meterBaseOffset
local meterSize
local meterOffset
local warningPulseTime

local flashTimer
local meterActive

local oldInit = init or function() end
local oldUpdate = update or function() end

function init()
  oldInit()
  
  message.setHandler("v-depthPoison-showMeter", showMeter)
  
  message.setHandler("v-depthPoison-hideMeter", hideMeter)

  message.setHandler("v-depthPoison-setRatio", function (_, _, ratio)
    displayPoisonRatio(ratio)
  end)
  
  message.setHandler("v-depthPoison-flash", flash)

  baseLayerImage = "/interface/v-depthpoisonmeter/base.png"
  fillLayerImage = "/interface/v-depthpoisonmeter/fill.png"
  flashLayerImage = "/interface/v-depthpoisonmeter/flash.png"
  warningLayerImage = "/interface/v-depthpoisonmeter/warning.png"
  
  poisonRatio = 0
  flashTime = 0.25
  meterBaseOffset = {0, 5}
  meterSize = root.imageSize(baseLayerImage)
  meterOffset = vec2.add(meterBaseOffset, vec2.mul(meterSize, -1 / 16))
  warningPulseTime = 5.0
  warningThreshold = 0.75  -- The minimum poison ratio required for the warning border to show.

  flashTimer = 0
  warningPulseTimer = warningPulseTime
  meterActive = false
end

function update(dt)
  oldUpdate(dt)  -- Drawables implicitly cleared.
  
  -- Show meter if active
  if meterActive then
    updateAnim(dt)
    updateTimers(dt)
  end
end

function showMeter()
  meterActive = true
end

function hideMeter()
  meterActive = false
end

function displayPoisonRatio(ratio)
  poisonRatio = ratio
end

function flash()
  flashTimer = flashTime
end

function updateAnim(dt)
  localAnimator.addDrawable({
    image = baseLayerImage,
    position = meterOffset,
    fullbright = true,
    centered = false
  }, "overlay+5")
  
  local cropHeight = math.floor(meterSize[2] * poisonRatio)
  
  localAnimator.addDrawable({
    image = fillLayerImage .. string.format("?crop=0;0;%d;%d", meterSize[1], cropHeight),
    position = meterOffset,
    fullbright = true,
    centered = false
  }, "overlay+5")
  
  local warningOpacity = math.floor(util.lerp(pingPong(warningPulseTimer / warningPulseTime), 0, 255))

  localAnimator.addDrawable({
    image = warningLayerImage .. string.format("?multiply=ffffff%02x", warningOpacity),
    position = meterOffset,
    fullbright = true,
    centered = false
  }, "overlay+5")
  
  local flashOpacity = math.floor(util.lerp(flashTimer / flashTime, 0, 255))

  localAnimator.addDrawable({
    image = flashLayerImage .. string.format("?multiply=ffffff%02x", flashOpacity),
    position = meterOffset,
    fullbright = true,
    centered = false
  }, "overlay+5")
end

function updateTimers(dt)
  flashTimer = math.max(0, flashTimer - dt)
  
  if poisonRatio >= warningThreshold then
    warningPulseTimer = warningPulseTimer - dt
    if warningPulseTimer <= 0 then
      warningPulseTimer = warningPulseTime
    end
  else
    warningPulseTimer = warningPulseTime
  end
end