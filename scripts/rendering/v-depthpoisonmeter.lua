require "/scripts/vec2.lua"
require "/scripts/util.lua"
require "/scripts/voidedutil.lua"

local baseLayerImage
local fillLayerImage
local flashLayerImage
local warningLayerImage
local shimmerLayerImage

local meterRenderLayer

local poisonRatio
local flashTime
local meterBaseOffset
local meterSize
local meterOffset
local warningPulseTime

local flashTimer
local meterActive

local shouldShimmer
local shimmerTime
local shimmerFrameCount

local oldInit = init or function() end
local oldUpdate = update or function() end

function init()
  oldInit()
  
  message.setHandler("v-depthPoison-showMeter", showMeter)
  
  message.setHandler("v-depthPoison-hideMeter", hideMeter)

  message.setHandler("v-depthPoison-setRatio", function(_, _, ratio)
    displayPoisonRatio(ratio)
  end)
  
  message.setHandler("v-depthPoison-flash", flash)
  
  message.setHandler("v-depthPoison-setShimmerTime", function(_, _, time)
    if time then
      shouldShimmer = true
      shimmerTime = time
    else
      shouldShimmer = false
      shimmerTimer = 0
    end
  end)

  baseLayerImage = "/interface/v-depthpoisonmeter/base.png"
  fillLayerImage = "/interface/v-depthpoisonmeter/fill.png"
  flashLayerImage = "/interface/v-depthpoisonmeter/flash.png"
  warningLayerImage = "/interface/v-depthpoisonmeter/warning.png"
  shimmerLayerImage = "/interface/v-depthpoisonmeter/shimmer.png"
  
  meterRenderLayer = "overlay+5"
  
  poisonRatio = 0
  flashTime = 0.25
  meterBaseOffset = {0, 5}
  meterSize = root.imageSize(baseLayerImage)
  meterOffset = vec2.add(meterBaseOffset, vec2.mul(meterSize, -1 / 16))
  warningPulseTime = 5.0
  warningThreshold = 0.75  -- The minimum poison ratio required for the warning border to show.
  
  shouldShimmer = false
  shimmerTime = nil
  shimmerFrameCount = 16

  flashTimer = 0
  shimmerTimer = 0
  warningPulseTimer = warningPulseTime
  meterActive = false
end

function update(dt)
  oldUpdate(dt)  -- Drawables implicitly cleared.
  
  -- Show meter if active
  if meterActive then
    updateAnim(dt)
    updateTimers(dt)
    drawShimmer(dt)
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
  }, meterRenderLayer)
  
  local cropHeight = math.floor(meterSize[2] * poisonRatio)
  
  localAnimator.addDrawable({
    image = fillLayerImage .. string.format("?crop=0;0;%d;%d", meterSize[1], cropHeight),
    position = meterOffset,
    fullbright = true,
    centered = false
  }, meterRenderLayer)
  
  local warningOpacity = math.floor(util.lerp(pingPong(warningPulseTimer / warningPulseTime), 0, 255))

  localAnimator.addDrawable({
    image = warningLayerImage .. string.format("?multiply=ffffff%02x", warningOpacity),
    position = meterOffset,
    fullbright = true,
    centered = false
  }, meterRenderLayer)
  
  local flashOpacity = math.floor(util.lerp(flashTimer / flashTime, 0, 255))

  localAnimator.addDrawable({
    image = flashLayerImage .. string.format("?multiply=ffffff%02x", flashOpacity),
    position = meterOffset,
    fullbright = true,
    centered = false
  }, meterRenderLayer)
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

function drawShimmer(dt)
  if shouldShimmer then
    shimmerTimer = shimmerTimer + dt
    if shimmerTimer > shimmerTime then
      shimmerTimer = 0
    end

    local frameNumber = math.floor(util.lerp(shimmerTimer / shimmerTime, 0, shimmerFrameCount))
    localAnimator.addDrawable({
      image = string.format("%s:%d", shimmerLayerImage, frameNumber),
      position = meterOffset,
      fullbright = true,
      centered = false
    }, meterRenderLayer)
  end
end