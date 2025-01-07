require "/scripts/rect.lua"
require "/scripts/vec2.lua"
require "/scripts/v-animator.lua"

local oldInit = init or function() end
local oldUpdate = update or function() end

local fadeTime
local startColor
local endColor
local minFallOffDistance
local maxFallOffDistance
local renderLayer

-- local titanId
local distance
local fadeTimer

-- Camera can pan 600 px, or 75 blocks at 1x zoom. Will need double this value to ensure full coverage of viewing
-- range.
local WINDOW_PADDING = 150

function init()
  oldInit()
  -- message.setHandler("v-titanOfDarknessAura-activate", function(_, _, id)
  --   titanId = id
  -- end)

  fadeTime = 10
  startColor = {94, 113, 128, 0}
  endColor = {18, 5, 20, 255}

  minFallOffDistance = 1000
  maxFallOffDistance = 1500
  renderLayer = "BackgroundOverlay-10"

  distance = 0
  fadeTimer = 0
end

function update(dt)
  oldUpdate(dt)

  local titanId = world.getProperty("v-activeTitanOfDarkness")

  if titanId and world.entityExists(titanId) then
    fadeTimer = math.min(fadeTime, fadeTimer + dt)
    distance = world.magnitude(entity.position(), world.entityPosition(titanId))
  else
    fadeTimer = math.max(0, fadeTimer - dt)
  end

  -- This uses a thick line to create a colored rectangle that covers the entire screen.
  local windowRegion = world.clientWindow()
  -- Make window region relative to the current entity.
  local relativeWindowRegion = rect.translate(windowRegion, vec2.mul(entity.position(), -1))
  local drawingBounds = rect.pad(relativeWindowRegion, WINDOW_PADDING)  -- Pad region to account for camera panning

  local verticalMidPoint = (drawingBounds[4] + drawingBounds[2]) / 2

  local fallOffAmount = 1 - math.max(0, distance - minFallOffDistance) / (maxFallOffDistance - minFallOffDistance)

  localAnimator.addDrawable({
    line = {{drawingBounds[1], verticalMidPoint}, {drawingBounds[3], verticalMidPoint}},
    position = {0, 0},
    width = (drawingBounds[4] - drawingBounds[2]) * 8,
    fullbright = false,
    color = vAnimator.lerpColor(fadeTimer / fadeTime * fallOffAmount, startColor, endColor)
  }, renderLayer)

  localAnimator.addDrawable({
    line = {{drawingBounds[1], verticalMidPoint}, {drawingBounds[3], verticalMidPoint}},
    position = {0, 0},
    width = (drawingBounds[4] - drawingBounds[2]) * 8,
    fullbright = false,
    color = vAnimator.lerpColor(fadeTimer / fadeTime * fallOffAmount, {94, 113, 128, 0}, {18, 5, 20, 100})
  }, "ForegroundOverlay+10")
end