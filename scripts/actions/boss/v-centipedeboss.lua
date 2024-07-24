require "/scripts/v-behavior.lua"
require "/scripts/voidedutil.lua"
require "/scripts/v-ellipse.lua"
require "/scripts/util.lua"

-- param gridDimensions
-- param coordDelimiter
-- param uniqueIdPrefix
-- param boardVarPrefix
function v_fetchPositions(args, board)
  local rq = vBehavior.requireArgsGen("v_fetchPositions", args)

  if not rq{"gridDimensions", "coordDelimiter", "uniqueIdPrefix", "boardVarPrefix"} then return false end

  -- For each coordinate in the grid...
  for x = 1, args.gridDimensions[1] do
    for y = 1, args.gridDimensions[2] do
      local uniqueId = string.format("%s%d%s%d", args.uniqueIdPrefix, x, args.coordDelimiter, y)
      local boardVar = string.format("%s%d%s%d", args.boardVarPrefix, x, args.coordDelimiter, y)

      local entityId = world.loadUniqueEntity(uniqueId)

      if not entityId or not world.entityExists(entityId) then
        sb.logWarn("v_fetchPositions: Could not find position with unique ID '%s'", uniqueId)
        return false
      end

      board:setPosition(boardVar, world.entityPosition(entityId))
    end
  end

  return true
end

-- output entityIds
function v_getChildren()
  return true, {entityIds = world.callScriptedEntity(self.childId, "getChildren")}
end

-- param children
-- param attackId
-- param target
-- param awaitChildren
function v_attackAllSegments(args)
  -- Prompts all child segments to attack.
  local rq = vBehavior.requireArgsGen("v_attackAllSegments", args)

  if not rq{"children", "attackId"} then return false end

  -- Send a message to each child segment to attack with ID attackId.
  for _, entityId in ipairs(args.children) do
    world.sendEntityMessage(entityId, "attack", entity.id(), args.attackId, args.target)
  end

  if args.awaitChildren then
    vBehavior.awaitNotification("finished", #args.children)
  end

  return true
end

-- param children
-- param attackId
-- param target
function v_attackRandomSegment(args)
  -- Prompts a random child segment to attack.
  local rq = vBehavior.requireArgsGen("v_attackRandomSegment", args)

  if not rq{"children", "attackId"} then return false end

  -- Send a message to a random child segment to attack with ID attackId.
  local entityId = args.children[math.random(1, #args.children)]
  world.sendEntityMessage(entityId, "attack", entity.id(), args.attackId, args.target)

  return true
end

-- param numTotalPoints: number - the number of points on the ellipse that the worm must reach for the constriction to
-- complete. Each point reached also advances progress toward the end radius and end center
-- param speed: number - the movement speed to use when constricting.
-- param controlForce: number - the control force with which to approach any target velocities while constricting
-- param tolerance: number - the maximum distance at which the worm can be considered "at" any ellipse point
-- param numPoints: number - the number of points to use in the ellipse
-- param startRadius: vec2 - starting x and y radius of the ellipse along which the worm orbits
-- param endRadius: vec2 - ending x and y radius of the ellipse along which the worm orbits
-- param startCenter: position - the starting center of the ellipse
-- param endCenter: position - the ending center of the ellipse
-- param bodyClampRate: number - the rate at which the body segments should turn themselves relative to their owners to
-- approach the ellipse, in degrees per second.
function v_wormConstrict(args, _, _, dt)
  -- Makes the worm constrict to a specific location.

  local rq = vBehavior.requireArgsGen("v_wormConstrict", args)

  if not rq{"numTotalPoints", "speed", "controlForce", "tolerance", "numPoints", "startRadius", "endRadius",
  "startCenter", "endCenter", "bodyClampRate"} then
    return false
  end

  local bodyClampRate = util.toRadians(args.bodyClampRate)

  -- Get the absolute angle of the distance from the center to the current position, which will be used as an offset in
  -- the calculations. This makes the worm start at the point on the ellipse that is closest to its current position.
  local offsetAngle = vec2.angle(world.distance(mcontroller.position(), args.startCenter))

  local ticker = 0  -- Counter that iterates through the points.

  while ticker < args.numTotalPoints do
    local radius = vec2.lerp(ticker / args.numTotalPoints, args.startRadius, args.endRadius)
    local center = vec2.lerp(ticker / args.numTotalPoints, args.startCenter, args.endCenter)

    local targetPos = vEllipse.point(center, radius, args.numPoints, ticker, offsetAngle)

    -- If the worm has reached the target position after flying for the current tick...
    if vBehavior.rotatedFlyToPositionTick(targetPos, args.speed, args.controlForce, args.tolerance) then
      -- Find the next point on the ellipse that is out of reach of the worm.
      repeat
        targetPos = vEllipse.point(center, radius, args.numPoints, ticker, offsetAngle)
        ticker = ticker + 1
      until world.magnitude(targetPos, mcontroller.position()) > args.tolerance
    end

    world.callScriptedEntity(self.childId, "trailAlongEllipse", center, radius, bodyClampRate)

    vEllipse.debug(center, radius, args.numPoints, "green")

    coroutine.yield()
  end

  return true
end