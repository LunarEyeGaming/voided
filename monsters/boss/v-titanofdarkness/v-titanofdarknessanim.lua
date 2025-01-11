require "/scripts/vec2.lua"
require "/scripts/interp.lua"
--[[
  A localAnimator script that adds a "blurring" effect by rendering `count` translucent copies of everything rendered by
  the current monster. These copies are placed in a radial formation at a radial offset of `radius` blocks and revolve
  around the center of the monster at a rate of `rotationRate` revolutions per second.
]]

local defaultArgs
local keyframedArgs
local keyframeTimer
local prevKeyframeId

local rotation

local dt

function init()
  defaultArgs = {
    radius = 1,
    count = 4,
    rotationRate = 1 / 4,
    visionAlpha = 128
  }
  rotation = 0
  dt = script.updateDt()
end

function update()
  localAnimator.clearDrawables()

  local portrait = world.entityPortrait(entity.id(), "full")

  updateKeyframedArgs()

  -- Get current arguments.
  local args = sb.jsonMerge(defaultArgs, animationConfig.animationParameter("titanAnimArgs"))
  -- Merge keyframedArgs on top of args.
  args = sb.jsonMerge(args, keyframedArgs)

  local pos = entity.position()

  for i = 1, args.count do
    local angleOffset = 2 * math.pi * i / args.count
    local startPos = vec2.add(pos, vec2.withAngle(angleOffset + rotation * 2 * math.pi, args.radius))

    for _, part in ipairs(portrait) do
      local transformation = {
        {part.transformation[1][1], part.transformation[1][2], part.transformation[1][3] * 0.125},
        {part.transformation[2][1], part.transformation[2][2], part.transformation[2][3] * 0.125},
        {part.transformation[3][1], part.transformation[3][2], part.transformation[3][3]}
      }
      localAnimator.addDrawable({
        image = part.image,
        position = vec2.add(startPos, vec2.mul(part.position, 0.125)),
        fullbright = part.fullbright,
        transformation = transformation,
        color = {part.color[1], part.color[2], part.color[3], args.visionAlpha},
        centered = false
      })
    end
  end
  rotation = rotation + args.rotationRate * dt
end

function updateKeyframedArgs()
  local keyframe = animationConfig.animationParameter("titanAnimKeyframe") or {}

  -- If the keyframe ID changed...
  if keyframe.id ~= prevKeyframeId then
    -- If the ID is not nil...
    if keyframe.id ~= nil then
      -- Set the timer to signal that a keyframe is active.
      keyframeTimer = 0
    else
      -- Unset the timer to signal that a keyframe is no longer active.
      keyframeTimer = nil
    end
  end

  -- If a keyframe is active...
  if keyframeTimer then
    keyframeTimer = keyframeTimer + dt  -- Decrease timer

    -- Update keyframedArgs.
    keyframedArgs = {}

    -- For each argument name and corresponding set of keyframe values...
    for arg, values in pairs(keyframe.values) do
      -- Interpolate between the two values and set the corresponding entry in keyframedArgs to the result.
      keyframedArgs[arg] = interp.linear(keyframeTimer / keyframe.duration, values.start, values.end_)
    end

    -- If more than keyframe.duration seconds have passed...
    if keyframeTimer >= keyframe.duration then
      keyframeTimer = nil  -- Unset the timer
    end
  end

  prevKeyframeId = keyframe.id
end