require "/scripts/util.lua"

vAnimator = {}

-- Camera can pan 600 px, or 75 blocks at 1x zoom. Will need double this value to ensure full coverage of viewing
-- range.
vAnimator.WINDOW_PADDING = 150

--- Updates a circular display of a stat. The circular display must have two parts.
---
--- Requires: `animator`
---
--- @param lPart string: The left part name of the display
--- @param rPart string: The right part name of the display
--- @param cur number: Current stat value
--- @param max number: Max stat value
--- @precondition 0.0 <= cur / max <= 1.0
function vAnimator.updateCircleBar(lPart, rPart, cur, max)
  local progress = cur / max
  animator.resetTransformationGroup(lPart)
  animator.resetTransformationGroup(rPart)

  if progress < 0.5 then
    animator.setAnimationState(rPart, "invisible")
    animator.rotateTransformationGroup(lPart, util.lerp((0.5 - progress) * 2, 0, -math.pi))
  else
    animator.setAnimationState(rPart, "visible")
    animator.rotateTransformationGroup(rPart, util.lerp((0.5 - (progress - 0.5)) * 2, 0, -math.pi))
  end
end

do
  local math_floor, math_max, math_min = math.floor, math.max, math.min

  ---Returns the linear interpolation between two RGBA colors with a given ratio. The resulting channels are in
  ---integer form and are capped between 0 and 255.
  ---
  ---Requires: None
  ---@param ratio number The amount of progress in the interpolation
  ---@param colorA ColorTable Starting color
  ---@param colorB ColorTable Ending color
  ---@return ColorTable
  function vAnimator.lerpColor(ratio, colorA, colorB)
    -- Return the linear interpolation of colorA and colorB with ratio, capped between 0 and 255 and in integer form.
    return {
      math_floor(math_max(math_min(colorA[1] + (colorB[1] - colorA[1]) * ratio, 255), 0)),
      math_floor(math_max(math_min(colorA[2] + (colorB[2] - colorA[2]) * ratio, 255), 0)),
      math_floor(math_max(math_min(colorA[3] + (colorB[3] - colorA[3]) * ratio, 255), 0)),
      math_floor(math_max(math_min(colorA[4] + (colorB[4] - colorA[4]) * ratio, 255), 0))
    }
  end
end

---Uncapped version of `vAnimator.lerpColor`.
---
---WARNING: This function does not check if `colorA` or `colorB` represent valid values, or that `ratio` is between 0
---and 1 inclusive.
---
---Requires: None
---@param ratio number The amount of progress in the interpolation
---@param colorA ColorTable Starting color
---@param colorB ColorTable Ending color
---@return ColorTable
function vAnimator.lerpColorU(ratio, colorA, colorB)
  -- Return the linear interpolation of colorA and colorB with ratio
  return {
    math.floor(colorA[1] + (colorB[1] - colorA[1]) * ratio),
    math.floor(colorA[2] + (colorB[2] - colorA[2]) * ratio),
    math.floor(colorA[3] + (colorB[3] - colorA[3]) * ratio),
    math.floor(colorA[4] + (colorB[4] - colorA[4]) * ratio)
  }
end

---Returns the linear interpolation between two RGB colors with a given ratio. Result is in integer form and capped
---between 0 and 255.
---
---Requires: None
---@param ratio number The amount of progress in the interpolation
---@param colorA ColorTable Starting color
---@param colorB ColorTable Ending color
---@return ColorTable
function vAnimator.lerpColorRGB(ratio, colorA, colorB)
  -- Return the linear interpolation of colorA and colorB with ratio, capped between 0 and 255 and in integer form.
  return {
    math.floor(math.max(math.min(colorA[1] + (colorB[1] - colorA[1]) * ratio, 255), 0)),
    math.floor(math.max(math.min(colorA[2] + (colorB[2] - colorA[2]) * ratio, 255), 0)),
    math.floor(math.max(math.min(colorA[3] + (colorB[3] - colorA[3]) * ratio, 255), 0))
  }
end


---Returns the string hexadecimal representation of a color table, with red, green, and blue values, as well as an
---optional alpha channel.
---
---Requires: None
---@param color ColorTable
---@return string
function vAnimator.colorToString(color)
  local rChannel = color[1]  -- red
  local gChannel = color[2]  -- green
  local bChannel = color[3]  -- blue
  local aChannel = color[4]  -- alpha

  -- Initial string
  local str = string.format("%02x%02x%02x", rChannel, gChannel, bChannel)

  -- If an alpha channel is provided, add it.
  if aChannel then
    str = string.format("%s%02x", str, aChannel)
  end

  return str
end

---Returns a color table containing the red, green, and blue channels represented by the hexadecimal color `str`. If the
---alpha channel is defined, that is also included in the table. If `str` is too short, `nil` is returned instead.
---
---Requires: None
---@param str string
---@return ColorTable?
function vAnimator.stringToColor(str)
  local result

  -- If the string is long enough to contain the red, green, and blue channels...
  if #str >= 6 then
    -- Convert each color component into a number. Alpha channel is nil if the string is not long enough.
    result = {
      tonumber(str:sub(1, 2), 16),
      tonumber(str:sub(3, 4), 16),
      tonumber(str:sub(5, 6), 16),
      #str == 8 and tonumber(str:sub(7, 8), 16) or nil
    }
  else
    result = nil
  end

  return result
end

-- TODO: Maybe rework this into an Animator class (and rename vAnimator to vAnimation to avoid confusion)

---Returns the frame number corresponding to a given time, provided a `frameCycle`, `numFrames`, and a `startFrame`.
---
---precondition: `0 <= frameTime <= frameCycle`
---@param frameTime number the time elapsed since the last frame cycle
---@param frameCycle number the amount of time it takes to complete one full cycle
---@param startFrame integer the number at which the frames start
---@param numFrames integer the number of frames in a cycle
---@return number
function vAnimator.frameNumber(frameTime, frameCycle, startFrame, numFrames)
  return math.floor(frameTime / frameCycle * numFrames) + startFrame
end

-- TODO: Maybe convert this to an instanced effect animator?
-- * Has a `template` parameter, a `duration` parameter, and a `keyframes` parameter (for keyframed attributes)
--   * Keyframes: `start: any`, `end: any`, `targetAttribute: string`
-- * The `add` method then takes in a table of overrides and makes a new instance with those overrides.

---@class LightningInstance
---@field startPos Vec2F
---@field endPos Vec2F
---@field ttl number

---@class LightningController
---@field _lightningCfg table
---@field _startColor ColorTable
---@field _endColor ColorTable
---@field _startOutlineColor ColorTable
---@field _endOutlineColor ColorTable
---@field _duration number
---@field _animateManually boolean
---@field _instances LightningInstance[]
---@field _setAnimParam fun(key: string, value: any)
vAnimator.LightningController = {}

---Instantiates a LightningController
---@param cfg table the lightning config to use
---@param startC ColorTable the start color of the lightning
---@param endC ColorTable the end color of the lightning
---@param dur number how long the lightning lasts
---@param animateManually boolean? whether or not to animate the colors manually.
---@param startOC ColorTable? the start outline color of the lightning
---@param endOC ColorTable? the end outline color of the lightning
---@return LightningController
function vAnimator.LightningController:new(cfg, startC, endC, dur, animateManually, startOC, endOC)
  if animateManually == nil then animateManually = true end

  local fields = {
    _lightningCfg = cfg,
    _startColor = startC,
    _endColor = endC,
    _startOutlineColor = startOC,
    _endOutlineColor = endOC,
    _duration = dur,
    _animateManually = animateManually,
    _instances = {},
    -- Choose the right function to use depending on the context
    _setAnimParam = (activeItem and activeItem.setScriptedAnimationParameter)
      or (monster and monster.setAnimationParameter)
      or (object and object.setAnimationParameter)
  }
  setmetatable(fields, self)
  self.__index = self

  return fields
end

---Add an instance of lightning.
function vAnimator.LightningController:add(startPos, endPos)
  table.insert(self._instances, {startPos = startPos, endPos = endPos, ttl = self._duration})
end

function vAnimator.LightningController:update(dt)
  local lightning = {}

  -- For each instance in self._instances (removable)...
  for i = #self._instances, 1, -1 do
    local instance = self._instances[i]

    if instance.ttl <= 0 then
      table.remove(self._instances, i)
    else
      local cfg = copy(self._lightningCfg)
      cfg.color = vAnimator.lerpColor(1 - instance.ttl / self._duration, self._startColor, self._endColor)
      if self._startOutlineColor then
        cfg.outlineColor = vAnimator.lerpColor(1 - instance.ttl / self._duration, self._startOutlineColor, self._endOutlineColor)
      end

      cfg.worldStartPosition = instance.startPos
      cfg.worldEndPosition = instance.endPos

      table.insert(lightning, cfg)
    end

    instance.ttl = instance.ttl - dt
  end

  self._setAnimParam("lightning", lightning)
end

---Sends the currently stored lightning instances to the local animator, clearing them from this LightningController.
---Use in place of `update` if desired.
function vAnimator.LightningController:flush()
  local lightning = {}

  -- For each instance in self._instances...
  for _, instance in ipairs(self._instances) do

    local cfg = copy(self._lightningCfg)
    cfg.startColor = self._startColor
    cfg.endColor = self._endColor
    cfg.worldStartPosition = instance.startPos
    cfg.worldEndPosition = instance.endPos

    table.insert(lightning, cfg)
  end

  self._instances = {}

  self._setAnimParam("lightning", lightning)
end

vLocalAnimator = {}

---@class VLocalAnimator_SpawnOffscreenParticlesArgs
---@field density number
---@field exposedOnly boolean
---@field vertical boolean?
---@field ignoreWind boolean?
---@field onMovementOnly boolean?
---@field pred (fun(pos: Vec2I): boolean)?

do
  -- State variable
  local prevWindowRegion

  ---Spawns particles with definition `particle` from offscreen with density `density`. If there is any wind, the x
  ---component of its initial velocity will be the wind level. Also spawns more or less particles depending on how much
  ---the client window has moved.
  ---
  ---NOTE: For performance reasons, this function will modify the particle's initial velocity.
  ---
  ---If `exposedOnly` is `true`, the `particle` will spawn only if the spawning position does not have a material in the
  ---background. The predicate function `pred` is optional. If defined, it adds an additional condition for the particle
  ---to spawn.
  ---
  ---@param particle table
  ---@param options VLocalAnimator_SpawnOffscreenParticlesArgs
  function vLocalAnimator.spawnOffscreenParticles(particle, options)
    local world_material = world.material
    local world_windLevel = world.windLevel
    local localAnimator_spawnParticle = localAnimator.spawnParticle
    local math_random = math.random

    local density = options.density
    local exposedOnly = options.exposedOnly
    local ignoreWind = options.ignoreWind
    local vertical = options.vertical
    local pred = options.pred or function() return true end

    -- Helper function.
    local spawnParticle = function(position)
      if math_random() <= density
          and (not exposedOnly or not world_material(position, "background"))
          and pred(position) then

        if not ignoreWind then
          -- Note: windLevel is zero if there is a background block.
          local horizontalSpeed = world_windLevel(position)

          if horizontalSpeed ~= 0 then
            local initialVelocity = particle.initialVelocity or {0, 0}
            initialVelocity[1] = horizontalSpeed
            particle.initialVelocity = initialVelocity
          end
        end

        localAnimator_spawnParticle(particle, position)
      end
    end

    local windowRegion = world.clientWindow()

    -- Define prevWindowRegion on first call
    if not prevWindowRegion then
      prevWindowRegion = windowRegion
    end

    local windowRegionXL, windowRegionYB, windowRegionXR, windowRegionYT
    if options.onMovementOnly then
      -- Fudge window region values to ensure that iteration occurs only when the window has moved.
      windowRegionXL = windowRegion[1] - 1
      windowRegionYB = windowRegion[2] - 1
      windowRegionXR = windowRegion[3] + 1
      windowRegionYT = windowRegion[4] + 1
    else
      windowRegionXL = windowRegion[1]
      windowRegionYB = windowRegion[2]
      windowRegionXR = windowRegion[3]
      windowRegionYT = windowRegion[4]
    end
    local prevWindowXLeft = world.nearestTo(windowRegion[1], prevWindowRegion[1])
    local prevWindowXRight = world.nearestTo(windowRegion[3], prevWindowRegion[3])
    for y = windowRegion[2], windowRegion[4] do
      -- Left
      for x = prevWindowXLeft, windowRegionXL do
        spawnParticle({x, y})
      end

      -- Right
      for x = windowRegionXR, prevWindowXRight do
        spawnParticle({x, y})
      end
    end

    if vertical then
      for x = windowRegion[1], windowRegion[3] do
        -- Bottom
        for y = prevWindowRegion[2], windowRegionYB do
          spawnParticle({x, y})
        end

        -- Top
        for y = windowRegionYT, prevWindowRegion[4] do
          spawnParticle({x, y})
        end
      end
    end

    prevWindowRegion = windowRegion
  end
end