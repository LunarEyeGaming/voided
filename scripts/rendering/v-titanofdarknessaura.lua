require "/scripts/rect.lua"
require "/scripts/vec2.lua"
require "/scripts/v-animator.lua"

local oldInit = init or function() end
local oldUpdate = update or function() end

local fadeTime
local bgStartColor
local bgEndColor
local fgStartColor
local fgEndColor
local bgRenderLayer
local fgRenderLayer
local minFallOffDistance
local maxFallOffDistance

local titanPositionPromise
local titanPosition
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
  bgStartColor = {94, 113, 128, 0}
  bgEndColor = {18, 5, 20, 255}
  fgStartColor = {94, 113, 128, 0}
  fgEndColor = {18, 5, 20, 100}
  bgRenderLayer = "BackgroundOverlay-10"
  fgRenderLayer = "ForegroundOverlay+10"

  minFallOffDistance = 1000
  maxFallOffDistance = 1500

  distance = 0
  fadeTimer = 0
end

function update(dt)
  oldUpdate(dt)

  updateTitanPosition()

  -- Update timers
  if titanPosition then
    fadeTimer = math.min(fadeTime, fadeTimer + dt)
    distance = world.magnitude(entity.position(), titanPosition)
  else
    fadeTimer = math.max(0, fadeTimer - dt)
  end

  drawOverlays()
end

---Asynchronously updates the position of the Titan as frequently as the server allows.
---@postconditions: upon titanPositionPromise finishing, titanPosition is modified and titanPositionPromise is unset
function updateTitanPosition()
  -- If no promise is pending...
  if not titanPositionPromise then
    -- Request the position of the Titan.
    titanPositionPromise = world.findUniqueEntity("v-titanofdarkness")
  end

  -- If the promise has finished...
  if titanPositionPromise:finished() then
    -- -- If the promise succeeded...
    -- if titanPositionPromise:succeeded() then
    --   -- Update position
    --   titanPosition = titanPositionPromise:result()
    -- else
    --   -- Set position to nil.
    --   titanPosition = nil
    -- end
    titanPosition = titanPositionPromise:result()

    -- Unset promise
    titanPositionPromise = nil
  end
end

function drawOverlays()
  world.debugText("Test", entity.position(), "green")
  -- This uses a thick line to create a colored rectangle that covers the entire screen.
  local windowRegion = world.clientWindow()
  -- Make window region relative to the current entity. Account for world wrapping.
  local relativeWindowRegion = rect.translate(windowRegion, vec2.mul(world.nearestTo(rect.center(windowRegion), entity.position()), -1))
  local drawingBounds = rect.pad(relativeWindowRegion, WINDOW_PADDING)  -- Pad region to account for camera panning

  local verticalMidPoint = (drawingBounds[4] + drawingBounds[2]) / 2

  local fallOffAmount = 1 - math.max(0, distance - minFallOffDistance) / (maxFallOffDistance - minFallOffDistance)

  -- Background overlay
  localAnimator.addDrawable({
    line = {{drawingBounds[1], verticalMidPoint}, {drawingBounds[3], verticalMidPoint}},
    position = {0, 0},
    width = (drawingBounds[4] - drawingBounds[2]) * 8,
    fullbright = false,
    color = vAnimator.lerpColor(fadeTimer / fadeTime * fallOffAmount, bgStartColor, bgEndColor)
  }, bgRenderLayer)

  -- Foreground overlay
  localAnimator.addDrawable({
    line = {{drawingBounds[1], verticalMidPoint}, {drawingBounds[3], verticalMidPoint}},
    position = {0, 0},
    width = (drawingBounds[4] - drawingBounds[2]) * 8,
    fullbright = false,
    color = vAnimator.lerpColor(fadeTimer / fadeTime * fallOffAmount, fgStartColor, fgEndColor)
  }, fgRenderLayer)
end