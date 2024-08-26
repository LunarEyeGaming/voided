require "/monsters/boss/v-centipedeboss/v-sharedfunctions.lua"
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

-- output entityId
function v_getTail()
  return true, {entityId = world.callScriptedEntity(self.childId, "getTail")}
end

-- param children
-- param attackId
-- param target
-- param awaitChildren
-- param step: number - the step size by which to iterate through the children. ex: 2 means every two children
-- param interval: number - the number of seconds to wait between each child. Set to 0 for no wait time.
function v_attackAllSegments(args)
  -- Prompts all child segments to attack.
  local rq = vBehavior.requireArgsGen("v_attackAllSegments", args)

  if not rq{"children", "attackId"} then return false end

  local step = args.step or 1

  -- Send a message to each child segment to attack with ID attackId.
  for i, entityId in ipairs(args.children) do
    if (i - 1) % step == 0 then
      world.sendEntityMessage(entityId, "attack", entity.id(), args.attackId, args.target)

      if args.interval and args.interval > 0 then
        util.run(args.interval, function() end)
      end
    end
  end

  if args.awaitChildren then
    vBehavior.awaitNotification("finished", #args.children)
  end

  return true
end

-- param children
-- param attackId
-- param target
-- param excludeChild: entity - (optional) a child to exclude from the list. Useful for random selection without
-- consecutive repeats
-- output selectedChild
function v_attackRandomSegment(args)
  -- Prompts a random child segment to attack.
  local rq = vBehavior.requireArgsGen("v_attackRandomSegment", args)

  if not rq{"children", "attackId"} then return false end

  local entityId
  -- Send a message to a random child segment to attack with ID attackId.
  repeat
    entityId = args.children[math.random(1, #args.children)]
  until entityId ~= args.excludeChild
  world.sendEntityMessage(entityId, "attack", entity.id(), args.attackId, args.target)

  return true, {selectedChild = entityId}
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

    local targetPos = vEllipse.point(center, radius, ticker, args.numPoints, offsetAngle)

    -- If the worm has reached the target position after flying for the current tick...
    if vBehavior.rotatedFlyToPositionTick(targetPos, args.speed, args.controlForce, args.tolerance) then
      -- Find the next point on the ellipse that is out of reach of the worm.
      repeat
        targetPos = vEllipse.point(center, radius, ticker, args.numPoints, offsetAngle)
        ticker = ticker + 1
      until world.magnitude(targetPos, mcontroller.position()) > args.tolerance
    end

    world.callScriptedEntity(self.childId, "trailAlongEllipse", center, radius, bodyClampRate)

    -- vEllipse.debug(center, radius, args.numPoints, "green")

    coroutine.yield(nil, {center = center, radius = radius})
  end

  return true
end

-- Rotates the turret to the current controller rotation if `shouldRotate` is `true`, returning `true` as well.
-- Otherwise, returns `false`.
-- param shouldRotate
function v_rotateTurretToDefault(args)
  if not args.shouldRotate then return false end

  animator.resetTransformationGroup("turret")
  animator.rotateTransformationGroup("turret", mcontroller.rotation())

  return true
end

-- Rotates the turret to point to the specified target, outputting the resulting aim vector and offset.
-- param target: entity - the target to which to point
-- param offset: vec2 - the base firing offset, which will be adjusted and returned.
-- output aimVector
-- output projectileOffset
function v_rotateTurret(args)
  local rq = vBehavior.requireArgsGen("v_rotateTurret", args)

  if not rq{"target", "offset"} then return false end

  local targetDistance = world.distance(world.entityPosition(args.target), mcontroller.position())

  -- Set baseAimAngle and targetMagnitude
  local baseAimAngle = vec2.angle(targetDistance)
  local targetMagnitude = vec2.mag(targetDistance)

  -- Compensate for off-center fire position.
  local offsetAimAngle = math.pi / 2 - math.acos(args.offset[1] / targetMagnitude)
  local aimAngle = baseAimAngle - offsetAimAngle

  animator.resetTransformationGroup("turret")
  animator.rotateTransformationGroup("turret", aimAngle)

  -- Calculate offset and aim vector here.
  return true, {aimVector = vec2.withAngle(aimAngle), projectileOffset = vec2.rotate(args.offset, aimAngle)}
end

function v_centipedeDeathAnimation(args)
  centipede.deathAnimation()

  return true
end

-- Handles the spawning of rays during the death animation.
-- param children
-- param tail
-- output rayIds
function v_centipedeRayAnimation(args)
  local rq = vBehavior.requireArgsGen("v_centipedeRayAnimation", args)

  if not rq{"children", "tail"} then return false end

  -- Build a list of all segments.
  local allSegments = copy(args.children)
  table.insert(allSegments, args.tail)
  table.insert(allSegments, entity.id())

  -- Some config parameters.
  local rayStartInterval = 1.5
  local rayIntervalMultiplier = 0.82
  local minRayInterval = 0.01
  local rayInterval = rayStartInterval
  local rays = {}

  local rayTimer = rayInterval
  local dt = script.updateDt()

  -- Start the ray spawning loop.
  while true do
    -- Update ray timer
    rayTimer = rayTimer - dt

    if rayTimer <= 0 then
      local segmentId

      -- Pick a segment that exists.
      repeat
        segmentId = allSegments[math.random(#allSegments)]
      until world.entityExists(segmentId)

      -- Ask to spawn ray.
      local rayId = world.callScriptedEntity(segmentId, "centipede.spawnRay")

      -- Add to table.
      table.insert(rays, rayId)

      -- Reset ray timer
      rayTimer = rayInterval

      -- Update ray interval, if greater than minimum ray interval.
      rayInterval = math.max(rayInterval * rayIntervalMultiplier, minRayInterval)
    end

    coroutine.yield(nil, {rayIds = rays})
  end
end