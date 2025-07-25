require "/scripts/rect.lua"
require "/scripts/vec2.lua"

require "/scripts/v-animator.lua"

local oldInit = init or function() end
local oldUpdate = update or function() end

local activeEffects

function init()
  oldInit()

  activeEffects = {}

  -- maps special effect names to special effect constructor calls
  local validSpecialEffects = {
    screenFlash = function(args)
      return v_ScreenFlash:new(args.startColor, args.endColor, args.fullbright, args.duration, args.renderLayer)
    end
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

    local effect = validSpecialEffects[kind](args)

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
---@return ScreenFlash
function v_ScreenFlash:new(startColor, endColor, fullbright, duration, renderLayer)
  local effectConfig = {
    startColor = startColor,
    endColor = endColor,
    fullbright = fullbright,
    duration = duration,
    timer = duration,
    renderLayer = renderLayer or "ForegroundOverlay+10"
  }
  setmetatable(effectConfig, self)
  self.__index = self

  return effectConfig
end

function v_ScreenFlash:process(dt)
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