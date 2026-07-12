require "/scripts/rect.lua"
require "/scripts/vec2.lua"
require "/scripts/util.lua"
require "/scripts/v-vec2.lua"

require "/scripts/v-animator.lua"
require "/scripts/v-entity.lua"

local oldInit = init or function() end
local oldUpdate = update or function() end

-- I'm tired of dealing with naming conflicts for helper functions, so I'm making these local.
local matMultiply
local screenToWorldPosition
local worldToLocalPosition
local rotateMat
local translateMat
local scaleMat
local playSound

local activeEffects
local sunConfig

function init()
  oldInit()

  sunConfig = root.assetJson("/sky.config:sun")

  util.setDebug(true)

  activeEffects = {}

  -- maps special effect names to special effect constructor calls
  local validSpecialEffects = {
    screenFlash = function(args, _)
      return v_ScreenFlash:new(args.startColor, args.endColor, args.fullbright, args.duration, args.renderLayer, args.delay)
    end,
    distantDrawable = function(args, position)
      return v_DistantDrawable:new(args, position)
    end,
    playSound = playSound
  }

  message.setHandler("v-invokeSpecialEffect", function(_, _, kind, args, onScreenOnly, position)
    -- Ignore the message if it gives an invalid special effect kind.
    if not validSpecialEffects[kind] then
      sb.logError("v-specialeffects.lua: Invalid special effect kind '%s'. Ignoring.", kind)
      return
    end

    -- world.clientWindow() returns a `RectI` containing the range of positions that are on-screen for the current
    -- client. It's undocumented.
    local windowRegion = world.clientWindow()
    -- Ignore the message if it is restricted to being on-screen only and it came from off-screen.
    if onScreenOnly and not rect.contains(windowRegion, position) then
      return
    end

    local effect = validSpecialEffects[kind](args, position)

    table.insert(activeEffects, effect)
  end)
end

function update(dt)
  oldUpdate(dt)  -- Implicitly clears drawables.

  -- Iterate through activeEffects, processing each entry and deleting it once it returns `true`.
  local i = 1
  while i <= #activeEffects do
    local effect = activeEffects[i]

    -- If the result of processing the entry is `true`, delete (and do not increment `i`).
    if effect:process(dt) then
      table.remove(activeEffects, i)
    else
      i = i + 1
    end
  end
end

-- Classes
-- These classes have the following interface (which will be called "SpecialEffect"):
-- * `table new(table effectConfig)`
-- * `boolean process(number dt)` - Evaluate the effect for one tick. Returns `true` if the effect is finished, `false`
--   otherwise. This method should not call `localAnimator.clearDrawables()` at any point as it WILL affect other
--   scripts.

---@class ScreenFlash
---@field startColor ColorTable
---@field endColor ColorTable
---@field fullbright boolean?
---@field duration number
---@field renderLayer string
v_ScreenFlash = {}

---Instantiates a screen flash.
---
---@param startColor ColorTable
---@param endColor ColorTable
---@param fullbright? boolean
---@param duration number
---@param renderLayer? string
---@param delay? number
---@return ScreenFlash
function v_ScreenFlash:new(startColor, endColor, fullbright, duration, renderLayer, delay)
  local effectConfig = {
    startColor = startColor,
    endColor = endColor,
    fullbright = fullbright,
    duration = duration,
    delay = delay,
    delayTimer = delay,
    timer = duration,
    renderLayer = renderLayer or "ForegroundOverlay+10"
  }
  setmetatable(effectConfig, self)
  self.__index = self

  return effectConfig
end

function v_ScreenFlash:process(dt)
  if self.delayTimer then
    self.delayTimer = self.delayTimer - dt
    if self.delayTimer <= 0 then
      self.delayTimer = nil
    end
    return
  end

  self.timer = self.timer - dt

  -- This uses a thick line to create a colored rectangle that covers the entire screen.
  local windowRegion = world.clientWindow()
  -- Make window region relative to the current entity.
  local relativeWindowRegion = rect.translate(windowRegion, vec2.mul(world.nearestTo(rect.center(windowRegion), entity.position()), -1))
  local drawingBounds = rect.pad(relativeWindowRegion, vAnimator.WINDOW_PADDING)  -- Pad region to account for camera panning

  local verticalMidPoint = (drawingBounds[4] + drawingBounds[2]) / 2

  localAnimator.addDrawable({
    line = {{drawingBounds[1], verticalMidPoint}, {drawingBounds[3], verticalMidPoint}},
    position = {0, 0},
    width = (drawingBounds[4] - drawingBounds[2]) * 8,
    fullbright = self.fullbright,
    -- Timer is decreasing, so endColor and startColor must be swapped.
    color = vAnimator.lerpColor(self.timer / self.duration, self.endColor, self.startColor)
  }, self.renderLayer)

  return self.timer <= 0
end

--[[
  keyFrames: List of records
    time: number
    screenPosition: Vec2F
    zPosition: number, between 0 and 1
    worldPosition: Vec2F
    scale: Vec2F
    rotation: number (degrees)

]]

local interpModes = {
  exp = function(ratio, a, b, power)
    return (b - a) * (ratio ^ power) + a
  end
}

---@class DistantDrawable_Keyframe
---@field time number
---@field screenPosition Vec2F
---@field zPosition number between 0 and 1
---@field worldPosition Vec2F
---@field scale Vec2F
---@field rotation number in degrees
---@field interpMode "exp"
---@field interpArgs any[]

---@class DistantDrawable
---@field image string
---@field keyFrames DistantDrawable_Keyframe[]
---@field fullbright boolean
---@field positionedAtSun boolean
---
---@field _keyFrameIdx integer
---@field _timer number
v_DistantDrawable = {}

---Instantiates a distant drawable.
---
---@param args table
---@return DistantDrawable
function v_DistantDrawable:new(args, position)
  local keyFrames = {}

  v_DistantDrawable.addKeyFrame(keyFrames, args.firstKeyFrame, position)

  local window = world.clientWindow()
  local windowSize = {window[3] - window[1], window[4] - window[2]}
  local MAX_ROLLING_AVG_CHECK = 10
  local clientWindowSizes = {}
  for i = 1, MAX_ROLLING_AVG_CHECK do
    clientWindowSizes[i] = windowSize
  end

  for _, keyFrame in ipairs(args.keyFrames) do
    v_DistantDrawable.addKeyFrame(keyFrames, keyFrame, position)
  end
  local effectConfig = {
    image = args.image,
    fullbright = args.fullbright,
    positionedAtSun = args.positionedAtSun,
    keyFrames = keyFrames,
    _keyFrameIdx = 2,
    _timer = 0,
    _clientWindowSizes = clientWindowSizes,
    _MAX_ROLLING_AVG_CHECK = MAX_ROLLING_AVG_CHECK,
    _clientWindowSizesIdx = 1
  }
  setmetatable(effectConfig, self)
  self.__index = self

  return effectConfig
end

function v_DistantDrawable:process(dt)
  self._predictedPos = vEntity.predictPosition(dt)
  self:calculateSmoothClientWindow()

  self._timer = self._timer + dt

  local keyFrameStart = self.keyFrames[self._keyFrameIdx - 1]
  local keyFrameEnd = self.keyFrames[self._keyFrameIdx]

  local ratio = self._timer / keyFrameEnd.time
  if keyFrameEnd.interpMode then
    local func = interpModes[keyFrameEnd.interpMode]
    local args = keyFrameEnd.interpArgs or {}
    if func then
      ratio = func(ratio, 0, 1, table.unpack(args))
    else
      sb.logError(string.format("v-specialeffects.lua: Unknown interpMode '%s' in keyframe %s", keyFrameEnd.interpMode, self._keyFrameIdx))
    end
  end
  local worldPos, scale
  scale = self:lerpKeyframeAttr("scale", vVec2.lerp, ratio, keyFrameStart, keyFrameEnd, {1, 1})
  if self.positionedAtSun then
    local sunScale
    worldPos, sunScale = self:sunPositionAndScale()
    scale = {sunScale * scale[1], sunScale * scale[2]}
  else
    worldPos = self:lerpPosition(ratio, keyFrameStart, keyFrameEnd)
  end
  -- local scale
  -- if keyFrameStart.scale or keyFrameEnd.scale then
  --   scale = vVec2.lerp(ratio, keyFrameStart.scale or keyFrameEnd.scale, keyFrameEnd.scale or keyFrameStart.scale)
  -- else
  --   scale = {1, 1}
  -- end
  -- local rotation
  -- if keyFrameStart.rotation or keyFrameEnd.rotation then
  --   rotation = util.lerp(ratio, keyFrameStart.rotation or keyFrameEnd.rotation, keyFrameEnd.rotation or keyFrameStart.rotation)
  -- else
  --   rotation = 0
  -- end
  local rotation = self:lerpKeyframeAttr("rotation", util.lerp, ratio, keyFrameStart, keyFrameEnd, 0)
  local color = self:lerpKeyframeAttr("color", vAnimator.lerpColor, ratio, keyFrameStart, keyFrameEnd)

  localAnimator.addDrawable({
    image = self.image,
    position = worldToLocalPosition(worldPos),
    transformation = rotateMat(rotation, scaleMat(scale)),
    fullbright = self.fullbright,
    color = color
  }, "BackgroundOverlay-20")

  if self._timer >= keyFrameEnd.time then
    self._keyFrameIdx = self._keyFrameIdx + 1
    self._timer = self._timer - keyFrameEnd.time
  end

  return self._keyFrameIdx > #self.keyFrames
end

function v_DistantDrawable:calculateSmoothClientWindow()
  local window = world.clientWindow()
  -- local ownPos = entity.position()
  -- local ownPosRounded = vec2.floor(vec2.add(ownPos, -0.05))
  -- local correctionAmount = vec2.sub(ownPos, ownPosRounded)
  -- self._clientWindowSizes[self._clientWindowSizesIdx] = {window[3] - window[1], window[4] - window[2]}
  -- self._clientWindowSizesIdx = self._clientWindowSizesIdx % self._MAX_ROLLING_AVG_CHECK + 1

  -- local sumX = 0
  -- local sumY = 0
  -- for _, windowSize in ipairs(self._clientWindowSizes) do
  --   sumX = sumX + windowSize[1]
  --   sumY = sumY + windowSize[2]
  -- end

  -- local avgWindowSizeX = sumX / #self._clientWindowSizes
  -- local avgWindowSizeY = sumY / #self._clientWindowSizes

  -- world.debugText("%s\n%s", avgWindowSizeX, avgWindowSizeY, entity.position(), "green")

  -- local correctedWindowLL = {window[1] + correctionAmount[1], window[2] + correctionAmount[2]}
  -- local correctedWindow = {correctedWindowLL[1], correctedWindowLL[2], correctedWindowLL[1] + avgWindowSizeX, correctedWindowLL[2] + avgWindowSizeY}

  -- local distanceFromLL = {30, 30}
  -- world.debugPoint(vec2.add({window[1], window[2]}, distanceFromLL), "red")
  -- world.debugPoint(vec2.add({correctedWindow[1], correctedWindow[2]}, distanceFromLL), "green")

  self._clientWindow = window

  -- if not record then
  --   record = {}
  --   shouldDumpRecord = true
  -- end
  -- record[vVec2.fToString(ownPos)] = {window = {window[1], window[2]}, correctedWindow = correctedWindowLL}
  -- if shouldDumpRecord and self._timer > 5 then
  --   for k, r in pairs(record) do
  --     local kV = vVec2.fFromString(k)
  --     sb.logInfo("%s | %s | %s", kV[1], r.window[1], r.correctedWindow[1])
  --   end
  --   shouldDumpRecord = false
  -- end

  -- util.debugRect(correctedWindow, "magenta")
end

function v_DistantDrawable:lerpPosition(ratio, frameStart, frameEnd)
  local zPosition = util.lerp(ratio, frameStart.zPosition, frameEnd.zPosition)

  local screenPos
  if frameStart.screenPosition or frameEnd.screenPosition then
    local screenPosStart = frameStart.screenPosition or frameEnd.screenPosition
    local screenPosEnd = frameEnd.screenPosition or frameStart.screenPosition
    screenPos = vVec2.lerp(ratio, screenPosStart, screenPosEnd)
  elseif zPosition == 1.0 then
    screenPos = {1.0, 1.0}
  else
    error("Screen position expected (zPosition ~= 1.0)")
  end

  local worldPos
  if frameStart.worldPosition or frameEnd.worldPosition then
    local worldPosStart = frameStart.worldPosition or frameEnd.worldPosition
    local worldPosEnd = frameEnd.worldPosition or frameStart.worldPosition
    worldPos = vVec2.lerp(ratio, worldPosStart, worldPosEnd)
  elseif zPosition == 0.0 then
    worldPos = {0, 0}
  else
    error("World position expected (zPosition ~= 0.0)")
  end

  local finalWorldPos = vVec2.lerp(
    zPosition,
    screenToWorldPosition(screenPos, self._clientWindow, self._predictedPos),
    worldPos
  )

  return finalWorldPos
end

function v_DistantDrawable:sunPositionAndScale()
  local window = world.clientWindow()
  -- Get pixel ratio. Estimate it if oSB isn't installed.
  local pixelRatio
  if camera and camera.pixelRatio then
    pixelRatio = camera.pixelRatio()
  else
    pixelRatio = vAnimator.MAX_CAMERA_SIZE_X / (window[3] - window[1])
  end

  -- Get camera position.
  local cameraPos
  if camera and camera.position then
    cameraPos = camera.position()
  else
    cameraPos = {(window[3] + window[1]) / 2, (window[4] - window[2]) / 2}
  end

  local time = world.timeOfDay()
  local sunRadius = sunConfig.radius
  local sunScale = sunConfig.scale
  -- Get relative sun position
  local sunPosRelative
  if renderer then
    -- Random mental gymnastics brought to you by the oSB source code!
    -- This does the exact calculations that determine where the sun is, then
    -- normalizes the position so that it maps properly depending on camera zoom.
    local basis = camera.screenSize()[2] / 1080
    local ratio = util.lerp(0.125, basis * 3, camera.pixelRatio())
    sunPosRelative = vec2.mul(
      vec2.rotate({sunRadius / 8, 0}, time * 2 * math.pi), ratio / camera.pixelRatio()
    )
    drawableScale = sunScale * ratio / pixelRatio
  else
    sunPosRelative = vec2.rotate({sunRadius / 8, 0}, time * 2 * math.pi)
    drawableScale = 1
  end

  return vec2.add(cameraPos, sunPosRelative), drawableScale
end

function v_DistantDrawable.addKeyFrame(keyFrames, keyFrame, position)
  local keyFrameCopy = copy(keyFrame)
  if keyFrameCopy.rotation then
    keyFrameCopy.rotation = util.toRadians(keyFrameCopy.rotation)
  end
  if keyFrameCopy.localPosition then
    keyFrameCopy.worldPosition = vec2.add(position, keyFrameCopy.localPosition)
  end
  table.insert(keyFrames, keyFrameCopy)
end

---Interpolates an attribute between two keyframes using function `func`.
---@param attr string
---@param func function
---@param ratio number
---@param frameStart table
---@param frameEnd table
---@param default any
---@return any
function v_DistantDrawable:lerpKeyframeAttr(attr, func, ratio, frameStart, frameEnd, default)
  local result
  if frameStart[attr] or frameEnd[attr] then
    result = func(ratio, frameStart[attr] or frameEnd[attr], frameEnd[attr] or frameStart[attr])
  else
    result = default
  end
  return result
end

---Converts a screen position to world position.
---@param screenPos Vec2F
---@param window RectI?
---@param ownPos Vec2F?
---@return table
function screenToWorldPosition(screenPos, window, ownPos)
  -- Use OpenStarbound functions if available.
  if camera and camera.screenToWorld and camera.screenSize then
    return camera.screenToWorld(vec2.mul(screenPos, camera.screenSize()))
  end

  window = window or world.clientWindow()
  -- ownPos = ownPos or entity.position()
  -- local ownPosRounded = vec2.floor(vec2.add(ownPos, 0.5))
  -- local correctionAmount = vec2.sub(ownPos, ownPosRounded)

  -- local correctedWindow = {window[1] + correctionAmount[1], window[2] + correctionAmount[2], window[3] + correctionAmount[1], window[4] + correctionAmount[2]}
  -- local correctedWindowCenter = rect.center(correctedWindow)

  -- world.debugText("%s\n%s\n%s\n%s", window, correctedWindow, ownPos, correctedWindowCenter, entity.position(), "green")

  -- util.debugRect(window, "yellow")

  -- util.debugRect(correctedWindow, "green")

  return {
    util.lerp(screenPos[1], window[1], window[3]),
    util.lerp(screenPos[2], window[2], window[4])
  }
end

function worldToLocalPosition(worldPos, relativeTo)
  relativeTo = relativeTo or entity.position()

  return vec2.sub(worldPos, relativeTo)
end

function matMultiply(m1, m2)
  return {
    {m1[1][1] * m2[1][1] + m1[1][2] * m2[2][1] + m1[1][3] * m2[3][1],
     m1[1][1] * m2[1][2] + m1[1][2] * m2[2][2] + m1[1][3] * m2[3][2],
     m1[1][1] * m2[1][3] + m1[1][2] * m2[2][3] + m1[1][3] * m2[3][3]},
    {m1[2][1] * m2[1][1] + m1[2][2] * m2[2][1] + m1[2][3] * m2[3][1],
     m1[2][1] * m2[1][2] + m1[2][2] * m2[2][2] + m1[2][3] * m2[3][2],
     m1[2][1] * m2[1][3] + m1[2][2] * m2[2][3] + m1[2][3] * m2[3][3]},
    {m1[3][1] * m2[1][1] + m1[3][2] * m2[2][1] + m1[3][3] * m2[3][1],
     m1[3][1] * m2[1][2] + m1[3][2] * m2[2][2] + m1[3][3] * m2[3][2],
     m1[3][1] * m2[1][3] + m1[3][2] * m2[2][3] + m1[3][3] * m2[3][3]}
  }
end

function identityMat()
  return {
    1, 0, 0,
    0, 1, 0,
    0, 0, 1
  }
end

function scaleMat(scale, mat)
  if mat then
    return matMultiply({
      {scale[1], 0, 0},
      {0, scale[2], 0},
      {0, 0, 1}
    }, mat)
  else
    return {
      {scale[1], 0, 0},
      {0, scale[2], 0},
      {0, 0, 1}
    }
  end
end

function rotateMat(angle, mat)
  if mat then
      return matMultiply({
      {math.cos(angle), -math.sin(angle), 0},
      {math.sin(angle), math.cos(angle), 0},
      {0, 0, 1}
    }, mat)
  else
    return {
      {math.cos(angle), -math.sin(angle), 0},
      {math.sin(angle), math.cos(angle), 0},
      {0, 0, 1}
    }
  end
end

function translateMat(vector, mat)
  if mat then
      return matMultiply({
      {1, 0, vector[1]},
      {0, 1, vector[2]},
      {0, 0, 1}
    }, mat)
  else
    return {
      {1, 0, vector[1]},
      {0, 1, vector[2]},
      {0, 0, 1}
    }
  end
end

function playSound(args)
  local sound
  if args.sounds then
    sound = args.sounds[math.random(#args.sounds)]
    localAnimator.playAudio(args.sounds[math.random(#args.sounds)])
  else
    sound = args.sound
    localAnimator.playAudio(args.sound, args.loops, args.volume)
  end

  local guiConfig = root.assetJson("/interface/scripted/v-positionlesssound/v-positionlesssound.config")
  guiConfig.args = {sound = sound, loops = args.loops, volume = args.volume}

  player.interact("ScriptPane", guiConfig)
end