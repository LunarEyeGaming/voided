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

local particleTimer

function init()
  oldInit()
  -- message.setHandler("v-titanOfDarknessAura-activate", function(_, _, id)
  --   titanId = id
  -- end)

  fadeTime = 10
  particleInterval = 0.5
  bgStartColor = {94, 113, 128, 0}
  bgEndColor = {18, 5, 20, 255}
  fgStartColor = {94, 113, 128, 0}
  fgEndColor = {18, 5, 20, 255}
  bgRenderLayer = "BackgroundOverlay-10"
  fgRenderLayer = "ForegroundOverlay+10"

  minFallOffDistance = 1000
  maxFallOffDistance = 1500

  distance = 0
  fadeTimer = 0
  particleTimer = particleInterval
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

  -- if fadeTimer == fadeTime then
  --   drawParticles(dt)
  -- end
  drawParticles(dt)
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
  world.debugText("v-titanofdarknessaura.lua::drawOverlays() called", entity.position(), "green")
  -- This uses a thick line to create a colored rectangle that covers the entire screen.
  local windowRegion = world.clientWindow()
  -- Make window region relative to the current entity. Account for world wrapping.
  local relativeWindowRegion = rect.translate(windowRegion, vec2.mul(world.nearestTo(rect.center(windowRegion), entity.position()), -1))
  local drawingBounds = rect.pad(relativeWindowRegion, vAnimator.WINDOW_PADDING)  -- Pad region to account for camera panning

  -- local horizontalMidPoint = (drawingBounds[3] + drawingBounds[1]) / 2
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
    -- line = {{drawingBounds[1], verticalMidPoint}, {drawingBounds[3], verticalMidPoint}},
    image = "/scripts/rendering/v-titanvignette.png",
    position = {0, 0},
    -- width = (drawingBounds[4] - drawingBounds[2]) * 8,
    fullbright = false,
    color = vAnimator.lerpColor(fadeTimer / fadeTime * fallOffAmount, fgStartColor, fgEndColor)
  }, fgRenderLayer)
end

function drawParticles(dt)
  if fadeTimer == 0 then return end

  particleTimer = particleTimer - dt

  if particleTimer <= 0 then

    local fallOffAmount = 1 - math.max(0, distance - minFallOffDistance) / (maxFallOffDistance - minFallOffDistance)
    local windowRegion = world.clientWindow()

    local leftPosition = {windowRegion[1], math.random() * (windowRegion[4] - windowRegion[2]) + windowRegion[2]}
    local rightPosition = {windowRegion[3], math.random() * (windowRegion[4] - windowRegion[2]) + windowRegion[2]}

    -- Note: windLevel is zero if there is a background block.
    local leftHorizontalSpeed = world.windLevel(leftPosition)
    if leftHorizontalSpeed == 0 then
      leftHorizontalSpeed = 10
    end
    local rightHorizontalSpeed = world.windLevel(rightPosition)
    if rightHorizontalSpeed == 0 then
      rightHorizontalSpeed = 10
    end

    -- if horizontalSpeed == 0 then
    --   horizontalSpeed = 10  -- Default speed
    -- end

    -- -- Determine horizontal spawning position
    -- local horizontalPosition

    -- if horizontalSpeed < 0 then
    --   horizontalPosition = windowRegion[3]
    -- else
    --   horizontalPosition = windowRegion[1]
    -- end

    -- local verticalPosition = math.random() * (windowRegion[4] - windowRegion[2]) + windowRegion[2]

    -- localAnimator.spawnParticle({
    --   type = "textured",
    --   image = "/scripts/rendering/v-titanparticles.png",
    --   initialVelocity = {horizontalSpeed, 0},
    --   approach = {2, 2},
    --   timeToLive = 10,
    --   destructionAction = "fade",
    --   destructionTime = 5,
    --   angularVelocity = 0,
    --   layer = "front",
    --   variance = {
    --     angularVelocity = 12,
    --     initialVelocity = {0, 10},
    --     finalVelocity = {0, 10}
    --   }
    -- }, vec2.add(entity.position(), {horizontalPosition, verticalPosition}))

    localAnimator.spawnParticle({
      type = "textured",
      image = "/scripts/rendering/v-titanparticles.png",
      initialVelocity = {leftHorizontalSpeed, 0},
      approach = {2, 2},
      timeToLive = 10,
      destructionAction = "fade",
      destructionTime = 5,
      angularVelocity = 0,
      layer = "front",
      color = vAnimator.lerpColor(fadeTimer / fadeTime * fallOffAmount, bgStartColor, bgEndColor),
      variance = {
        angularVelocity = 12,
        initialVelocity = {0, 10},
        finalVelocity = {0, 10}
      }
    }, leftPosition)

    localAnimator.spawnParticle({
      type = "textured",
      image = "/scripts/rendering/v-titanparticles.png",
      initialVelocity = {rightHorizontalSpeed, 0},
      approach = {2, 2},
      timeToLive = 10,
      destructionAction = "fade",
      destructionTime = 5,
      angularVelocity = 0,
      layer = "front",
      color = vAnimator.lerpColor(fadeTimer / fadeTime * fallOffAmount, bgStartColor, bgEndColor),
      variance = {
        angularVelocity = 12,
        initialVelocity = {0, 10},
        finalVelocity = {0, 10}
      }
    }, rightPosition)

    local velocity = world.entityVelocity(entity.id())
    particleTimer = particleInterval / (math.sqrt(vec2.mag(velocity)) + 1)
  end
end