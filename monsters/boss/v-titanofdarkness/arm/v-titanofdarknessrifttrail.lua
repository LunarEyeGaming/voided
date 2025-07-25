require "/scripts/vec2.lua"
require "/scripts/poly.lua"

local trails
local maxTrackDuration
local thicknessVariance

local trackedPositions
local prevPosition

local oldInit = init or function() end
local oldUpdate = update or function() localAnimator.clearDrawables() end

function init()
  oldInit()

  trails = animationConfig.animationParameter("riftTrails")
  maxTrackDuration = animationConfig.animationParameter("riftTrailDuration") * 60
  thicknessVariance = animationConfig.animationParameter("riftTrailThicknessVariance") or 0.25

  trackedPositions = {}
end

function update(dt)
  oldUpdate(dt)

  updateTrackedPositions()
  updateTrail()
end

function updateTrackedPositions()
  local currentPosition
  -- If the tracking entity is defined and exists...
  local trackingEntity = animationConfig.animationParameter("riftTrailTrackingEntity")
  if trackingEntity and world.entityExists(trackingEntity) then
    -- If trackedPositions has a length of maxTrackDuration or more...
    if #trackedPositions >= maxTrackDuration then
      table.remove(trackedPositions, 1)  -- Delete the first (oldest) element
    end
    -- table.insert(trackedPositions, world.entityPosition(trackingEntity))  -- Add to table.
    currentPosition = world.entityPosition(trackingEntity)

    -- Do some pre-computations and insert if there is a prevPosition that is not equal to currentPosition.
    if prevPosition and not vec2.eq(prevPosition, currentPosition) then
      local direction = world.distance(prevPosition, currentPosition)
      local mag = vec2.mag(direction)
      local inverseMag = 1 / mag
      table.insert(trackedPositions, {
        direction = direction,
        mag = mag,
        sinDirection = direction[2] * inverseMag,
        cosDirection = direction[1] * inverseMag,
        pos = currentPosition,
        topThicknessMultiplier = math.random() * (2 * thicknessVariance) + 1 - thicknessVariance,
        bottomThicknessMultiplier = math.random() * (2 * thicknessVariance) + 1 - thicknessVariance
      })
    end
  -- elseif #trackedPositions > 0 then
  --   table.remove(trackedPositions, 1)  -- Delete the first (oldest) element
  else
    currentPosition = nil

    if #trackedPositions > 0 then
      table.remove(trackedPositions, 1)  -- Delete the first (oldest) element
    end
  end

  prevPosition = currentPosition
end

function updateTrail()
  if #trackedPositions > 1 then
    -- For each trail...
    for _, trail in ipairs(trails) do
      local halfTrailThickness = trail.thickness / 2
      -- For each tracked position...
      for i = 1, #trackedPositions - 1 do
        local startProgress = (i + 1) / #trackedPositions
        local endProgress = i / #trackedPositions
        local startPos = trackedPositions[i].pos
        local distance = trackedPositions[i].mag
        local sinStart = trackedPositions[i + 1].sinDirection
        local cosStart = trackedPositions[i + 1].cosDirection
        local sinEnd = trackedPositions[i].sinDirection
        local cosEnd = trackedPositions[i].cosDirection
        local topThicknessStart = trackedPositions[i + 1].topThicknessMultiplier
        local bottomThicknessStart = trackedPositions[i + 1].bottomThicknessMultiplier
        local topThicknessEnd = trackedPositions[i].topThicknessMultiplier
        local bottomThicknessEnd = trackedPositions[i].bottomThicknessMultiplier

        local trailPoly = {
          {
            -startProgress * halfTrailThickness * sinStart * topThicknessStart,
            startProgress * halfTrailThickness * cosStart * topThicknessStart,
          },
          {
            startProgress * halfTrailThickness * sinStart * bottomThicknessStart,
            -startProgress * halfTrailThickness * cosStart * bottomThicknessStart,
          },
          {
            distance * cosEnd + endProgress * halfTrailThickness * sinEnd * bottomThicknessEnd,
            distance * sinEnd - endProgress * halfTrailThickness * cosEnd * bottomThicknessEnd,
          },
          {
            distance * cosEnd - endProgress * halfTrailThickness * sinEnd * topThicknessEnd,
            distance * sinEnd + endProgress * halfTrailThickness * cosEnd * topThicknessEnd,
          }
        }

        localAnimator.addDrawable({
          poly = trailPoly,
          color = trail.color,
          position = startPos,
          fullbright = trail.fullbright
        }, trail.renderLayer)
      end
    end
  end
end