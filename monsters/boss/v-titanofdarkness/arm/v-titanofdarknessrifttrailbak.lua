--[[
  class CappedQueue
    field items
    field maxLength
    field startIdx
    field length
    method CappedQueue(maxLength, initialValue)
      items = {}
      for i = 1, #maxLength do
        items[i] = initialValue
      end
      this.maxLength = maxLength
      startIdx = 1
      length = 0
    end
    method insert(elt)
      local oldElt = items[startIdx]
      items[startIdx] = elt
      startIdx = (startIdx + 1) % maxLength
      length = math.min(length + 1, maxLength)
    end
    method dequeue()
      local elt = items[startIdx - 1]
      items[startIdx - 1] = nil
      startIdx = (startIdx - 1) % maxLength
      length = length - 1
    end
  end
]]

require "/scripts/vec2.lua"
require "/scripts/poly.lua"

local maxTrackDuration
local trackedPositions

local timer
local debugPoly

function init()
  maxTrackDuration = 60
  trackedPositions = {}

  timer = 60

  debugPoly = {}
end

function update(dt)
  updateTrackedPositions()
  updateTrail()

  -- for i = 1, #debugPoly - 1 do
  --   local angle = vec2.angle(world.distance(debugPoly[i], debugPoly[i + 1]))
  --   world.debugLine(debugPoly[i], debugPoly[i + 1], "green")
  --   world.debugLine(debugPoly[i + 1], vec2.add(debugPoly[i + 1], vec2.rotate({0.25, 0.25}, angle)), "green")
  --   world.debugLine(debugPoly[i + 1], vec2.add(debugPoly[i + 1], vec2.rotate({0.25, -0.25}, angle)), "green")
  --   world.debugText("%s", i, debugPoly[i], "green")
  -- end
end

function updateTrackedPositions()
  -- If the tracking entity is defined and exists...
  local trackingEntity = animationConfig.animationParameter("trackingEntity")
  if trackingEntity and world.entityExists(trackingEntity) then
    -- If trackedPositions has a length of maxTrackDuration or more...
    if #trackedPositions >= maxTrackDuration then
      table.remove(trackedPositions, 1)  -- Delete the first (oldest) element
    end
    table.insert(trackedPositions, world.entityPosition(trackingEntity))  -- Add to table.
  else
    trackedPositions = {}
  end
end

function updateTrail()
  localAnimator.clearDrawables()

  if #trackedPositions > 1 then
    -- local trailPoly = {}  -- Top (and later bottom) part of each segment
    -- local trailPolyBottom = {}  -- Bottom part of each segment
    -- For each adjacent pair of tracked positions...
    for i = 1, #trackedPositions - 1 do
      -- Calculate progress of each one.
      local startProgress = i / #trackedPositions
      local endProgress = (i + 1) / #trackedPositions
      local startPos = trackedPositions[i]
      local endPos = trackedPositions[i + 1]

      -- Calculate startAngle, endAngle, and distance. endAngle = startAngle if this is the last pair of positions.
      local startAngle = vec2.angle(world.distance(startPos, endPos))
      local endAngle
      if i ~= #trackedPositions - 1 then
        endAngle = vec2.angle(world.distance(endPos, trackedPositions[i + 2]))
      else
        endAngle = startAngle
      end
      local distance = world.magnitude(endPos, startPos)
      -- Make trail polygon. Use two separate angles to make the connections seamless.
      local trailPoly = {
        vec2.rotate({0, endProgress}, endAngle),
        vec2.rotate({0, -endProgress}, endAngle),
        vec2.rotate({distance, -startProgress}, startAngle),
        vec2.rotate({distance, startProgress}, startAngle)
      }

      localAnimator.addDrawable({
        poly = poly.translate(trailPoly, endPos)
        -- poly = poly.rotate(targetPoly, angle)
      })
      -- -- Add polygon segment
      -- table.insert(trailPoly, vec2.add(endPos, vec2.rotate({0, endProgress}, endAngle)))
      -- table.insert(trailPolyBottom, vec2.add(endPos, vec2.rotate({0, -endProgress}, endAngle)))
    end

    -- -- for i, point in ipairs(trailPoly) do
    -- --   world.debugPoint(point, "yellow")
    -- --   world.debugText("%s", i, point, "yellow")
    -- -- end

    -- -- Insert bottom parts in reverse order
    -- for i = #trailPolyBottom, 1, -1 do
    -- -- for i = 1, #trailPolyBottom do
    --   table.insert(trailPoly, trailPolyBottom[i])
    --   -- world.debugPoint(trailPolyBottom[i], "green")
    --   -- world.debugText("%s", i, trailPolyBottom[i], "green")
    -- end

    -- -- sb.logInfo("%s", trailPoly[1])

    -- timer = timer - 1
    -- if timer <= 0 then
    --   debugPoly = {}
    --   for _, point in ipairs(trailPoly) do
    --     table.insert(debugPoly, point)
    --   end
    --   timer = 60
    -- end

    -- for i = 1, #trailPoly - 1 do
    --   local angle = vec2.angle(world.distance(trailPoly[i], trailPoly[i + 1]))
    --   world.debugLine(trailPoly[i], trailPoly[i + 1], "green")
    --   world.debugLine(trailPoly[i + 1], vec2.add(trailPoly[i + 1], vec2.rotate({0.25, 0.25}, angle)), "green")
    --   world.debugLine(trailPoly[i + 1], vec2.add(trailPoly[i + 1], vec2.rotate({0.25, -0.25}, angle)), "green")
    --   -- world.debugText("%s", i, trailPoly[i], "green")
    -- end

    -- world.debugPoint(trailPoly[1], "orange")
    -- world.debugPoint(trailPoly[#trailPoly], "blue")

    -- localAnimator.addDrawable({
    --   poly = trailPoly
    -- })

    -- -- localAnimator.addDrawable({
    -- --   poly = poly.translate({{0, 0}, {0, 1}, {1, 2}, {2, 2}, {2, 1}, {1, 0.5}, {1, -0.5}, {2, -1}, {2, -2}, {1, -2}, {0, -1}}, trackedPositions[1])
    -- -- })

  end
end