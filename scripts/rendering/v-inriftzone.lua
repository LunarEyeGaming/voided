require "/scripts/rect.lua"
require "/scripts/vec2.lua"
require "/scripts/v-animator.lua"

local oldInit = init or function() end
local oldUpdate = update or function() end

local fadeTime
local clientWindowWidthAt3x
local baseScale
local pulsatePeriod
local pulsateAmpStart
local pulsateAmpEnd
local pulsateCrescendoTime  -- Amount of time it takes for pulsation to reach max intensity.

local fgStartColor
local fgEndColor
local fgRenderLayer

local pulsateTimer
local fadeTimer

function init()
  oldInit()
  -- message.setHandler("v-titanOfDarknessAura-activate", function(_, _, id)
  --   titanId = id
  -- end)
  clientWindowWidthAt3x = 81
  -- width / clientWindowWidthAt3x (so a larger window corresponds to a higher scale)
  baseScale = 1
  pulsatePeriod = 1
  pulsateAmpStart = 0.0
  pulsateAmpEnd = 0.05
  pulsateCrescendoTime = 10

  fadeTime = 1

  fgStartColor = {94, 113, 128, 0}
  fgEndColor = {94, 113, 128, 127}
  fgRenderLayer = "ForegroundOverlay+10"

  pulsateTimer = 0
  fadeTimer = 0
end

function update(dt)
  oldUpdate(dt)

  local isInRift = status.uniqueStatusEffectActive("v-riftdestabilization")

  -- Update timers
  if isInRift then
    fadeTimer = math.min(fadeTime, fadeTimer + dt)
    pulsateTimer = pulsateTimer + dt
  else
    fadeTimer = math.max(0, fadeTimer - dt)
    pulsateTimer = 0
  end

  v_inRiftZone_drawOverlays()
end

function v_inRiftZone_drawOverlays()
  -- This uses a thick line to create a colored rectangle that covers the entire screen.
  local windowRegion = world.clientWindow()
  -- Make window region relative to the current entity. Account for world wrapping.
  local relativeWindowRegion = rect.translate(windowRegion, vec2.mul(world.nearestTo(rect.center(windowRegion), entity.position()), -1))

  -- Calculate scaleMultiplier based on the width of the camera
  local width = relativeWindowRegion[3] - relativeWindowRegion[1]
  local scaleMultiplier = width / clientWindowWidthAt3x

  -- local horizontalMidPoint = (drawingBounds[3] + drawingBounds[1]) / 2

  local crescendoProgress = pulsateTimer / pulsateCrescendoTime
  local pulsatePeriodicTimer = (pulsateTimer % pulsatePeriod)
  local scale = baseScale + util.lerp(crescendoProgress, pulsateAmpStart, pulsateAmpEnd) * math.sin(pulsatePeriodicTimer / pulsatePeriod * 2 * math.pi)
  scale = scale * scaleMultiplier

  -- Foreground overlay
  localAnimator.addDrawable({
    image = "/scripts/rendering/v-titanvignette.png",
    position = {0, 0},
    fullbright = true,
    color = vAnimator.lerpColor(fadeTimer / fadeTime, fgStartColor, fgEndColor),
    scale = scale
  }, fgRenderLayer)
end