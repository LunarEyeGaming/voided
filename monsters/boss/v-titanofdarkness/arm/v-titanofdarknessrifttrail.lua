require "/scripts/vec2.lua"
require "/scripts/poly.lua"

local maxTrackDuration
local trackedPositions

local trails

local oldInit = init or function() end
local oldUpdate = update or function() localAnimator.clearDrawables() end

function init()
  oldInit()

  trails = animationConfig.animationParameter("riftTrails")
  maxTrackDuration = animationConfig.animationParameter("riftTrailDuration") * 60

  trackedPositions = {}
end

function update(dt)
  oldUpdate(dt)

  updateTrackedPositions()
  updateTrail()
end

function updateTrackedPositions()
  -- If the tracking entity is defined and exists...
  local trackingEntity = animationConfig.animationParameter("riftTrailTrackingEntity")
  if trackingEntity and world.entityExists(trackingEntity) then
    -- If trackedPositions has a length of maxTrackDuration or more...
    if #trackedPositions >= maxTrackDuration then
      table.remove(trackedPositions, 1)  -- Delete the first (oldest) element
    end
    table.insert(trackedPositions, world.entityPosition(trackingEntity))  -- Add to table.
  elseif #trackedPositions > 0 then
    table.remove(trackedPositions, 1)  -- Delete the first (oldest) element
  end
end

function updateTrail()
  if #trackedPositions > 1 then
    -- For each trail...
    for _, trail in ipairs(trails) do
      local halfTrailThickness = trail.thickness / 2
      -- For each adjacent pair of tracked positions...
      for i = 1, #trackedPositions - 1 do
        -- Note: Higher index = newer
        -- Calculate progress of each pair.
        local startProgress = (i + 1) / #trackedPositions
        local endProgress = i / #trackedPositions
        local startPos = trackedPositions[i + 1]
        local endPos = trackedPositions[i]

        -- -- Calculate startAngle, endAngle, and distance. startAngle = endAngle if this is the last pair of positions.
        -- local endAngle = vec2.angle(world.distance(endPos, startPos))
        -- local startAngle
        -- if i ~= #trackedPositions - 1 then
        --   startAngle = vec2.angle(world.distance(startPos, trackedPositions[i + 2]))
        -- else
        --   startAngle = endAngle
        -- end
        -- local distance = world.magnitude(startPos, endPos)

        -- -- Make trail polygon segment. The first two points are the top and bottom parts of the beginning of the segment.
        -- -- The last two points are the top and bottom parts of the end of the segment.
        -- -- Use two separate directions to make the connections seamless.
        -- local trailPoly = {
        --   vec2.rotate({0, startProgress * halfTrailThickness}, startAngle),
        --   vec2.rotate({0, -startProgress * halfTrailThickness}, startAngle),
        --   vec2.rotate({distance, -endProgress * halfTrailThickness}, endAngle),
        --   vec2.rotate({distance, endProgress * halfTrailThickness}, endAngle)
        -- }

        -- localAnimator.addDrawable({
        --   poly = poly.translate(trailPoly, startPos),
        --   color = trail.color,
        --   fullbright = trail.fullbright
        -- }, trail.renderLayer)

        -- Calculate starting direction, ending direction, and distance. Starting direction = ending direction if this
        -- is the last pair of positions.
        local endDirection = world.distance(endPos, startPos)
        local startDirection
        if i ~= #trackedPositions - 1 then
          startDirection = world.distance(startPos, trackedPositions[i + 2])
        else
          startDirection = endDirection
        end
        local distance = world.magnitude(startPos, endPos)

        -- Store results of division b/c division is slower than multiplication.
        local inverseStartMag = 1 / vec2.mag(startDirection)
        local inverseEndMag = 1 / vec2.mag(endDirection)

        -- Also store results of sine and cosine calculations for start and end direction (but with trig functions out of the
        -- equation).
        local sinStart = startDirection[2] * inverseStartMag
        local cosStart = startDirection[1] * inverseStartMag
        local sinEnd = endDirection[2] * inverseEndMag
        local cosEnd = endDirection[1] * inverseEndMag

        local trailPoly = {
          {
            startPos[1] - startProgress * halfTrailThickness * sinStart,
            startPos[2] + startProgress * halfTrailThickness * cosStart,
          },
          {
            startPos[1] + startProgress * halfTrailThickness * sinStart,
            startPos[2] - startProgress * halfTrailThickness * cosStart,
          },
          {
            startPos[1] + distance * cosEnd + endProgress * halfTrailThickness * sinEnd,
            startPos[2] + distance * sinEnd - endProgress * halfTrailThickness * cosEnd,
          },
          {
            startPos[1] + distance * cosEnd - endProgress * halfTrailThickness * sinEnd,
            startPos[2] + distance * sinEnd + endProgress * halfTrailThickness * cosEnd,
          },
        }

        localAnimator.addDrawable({
          poly = trailPoly,
          color = trail.color,
          fullbright = trail.fullbright
        }, trail.renderLayer)
      end
    end
  end
end