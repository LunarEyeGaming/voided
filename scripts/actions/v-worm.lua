
require "/scripts/util.lua"
require "/scripts/vec2.lua"

-- Returns Cartesian coordinates for a point in the figure 8 given a period and time.
-- Errors if time > period or time < 0
function v_figure8(size, period, time)
  if time < 0 or time > period then
    error("v_figure8: time must be between 0 and period")
  end

  local ratio = time / (period * 2)  -- period is multiplied by 2 to account for skipped values resulting in half the period
  local theta = 2 * math.pi * ratio
  
  -- Remap theta to skip over the ranges where the lemniscate curve is undefined. Angles that lead to the left bulb are
  -- reversed
  if math.pi / 4 < theta and theta < 3 * math.pi / 4 then
    theta = -theta - math.pi / 2
  elseif 3 * math.pi / 4 <= theta and theta <= 5 * math.pi / 4 then
    theta = theta + math.pi
  elseif 5 * math.pi / 4 < theta and theta < 7 * math.pi / 4 then
    theta = -theta - 3 * math.pi / 2
  elseif 7 * math.pi / 4 <= theta and theta <= 2 * math.pi then
    theta = theta + 2 * math.pi
  -- Otherwise, theta is not a valid value; handled by error case at the beginning.
  end

  -- Calculate radius corresponding to theta using the polar equation for the lemniscate curve
  local radius = size * math.sqrt(math.cos(2 * theta))
  
  return {radius * math.cos(theta), radius * math.sin(theta)}
end

-- Flies to a given position with a provided speed and tolerance as well as controlForce
function v_flyToPos(pos, speed, controlForce, tolerance)
  local distance
  repeat
    distance = world.distance(pos, mcontroller.position())
    mcontroller.controlApproachVelocity(vec2.mul(vec2.norm(distance), speed), controlForce)

    -- Rotate to velocity
    local rotation = vec2.angle(mcontroller.velocity())
    mcontroller.setRotation(rotation)
    animator.resetTransformationGroup("body")
    animator.rotateTransformationGroup("body", rotation)

    mcontroller.controlFace(1)
    
    coroutine.yield()
  until math.abs(distance[1]) < tolerance and math.abs(distance[2]) < tolerance
end


-- param entity
-- param turnSpeed
-- param wavePeriod
-- param waveAmplitude
-- output angle
-- output direction
function v_approachTurnWorm(args, output, _, dt)
  local targetPosition = world.entityPosition(args.entity)
  local distance = world.magnitude(targetPosition, mcontroller.position())
  local timer = 0
  local lastSineAngle = 0
  while true do
    local toTarget = world.distance(targetPosition, mcontroller.position())
    local angle = mcontroller.rotation()

    local targetAngle = vec2.angle(toTarget)
    local diff = util.angleDiff(angle, targetAngle)
    if diff ~= 0 then
      angle = angle + (util.toDirection(diff) * args.turnSpeed) * dt
      if util.angleDiff(angle, targetAngle) * diff < 0 then
        angle = targetAngle
      end
    end
    
    timer = timer + dt

    -- Add a little bit of waviness to the movement
    local sineAngle = args.waveAmplitude * math.sin(timer * 2 * math.pi / args.wavePeriod)
    angle = angle + sineAngle - lastSineAngle
    lastSineAngle = sineAngle

    local speed = mcontroller.baseParameters().flySpeed
    mcontroller.controlApproachVelocity(vec2.withAngle(angle, speed), mcontroller.baseParameters().airForce, true)
    mcontroller.controlApproachVelocityAlongAngle(angle + math.pi * 0.5, 0, 50, false)
    mcontroller.setRotation(vec2.angle(mcontroller.velocity()))

    coroutine.yield(nil, {angle = angle, direction = diff})

    targetPosition = world.entityPosition(args.entity)
    distance = world.magnitude(targetPosition, mcontroller.position())
  end
end

-- param fireCount
-- param fireInterval
-- param target
function v_wormFire(args, board)
  -- Create a list of segment numbers, shuffle, then use the first <fireCount>. Send a message to the child segment to 
  -- fire the given segment, which will be propagated to the appropriate segment.
  local numSegments = config.getParameter("size")
  local segmentOrder = {}
  
  for i = 1, numSegments do
    segmentOrder[i] = i
  end
  
  shuffle(segmentOrder)
  
  for i = 1, args.fireCount do
    world.sendEntityMessage(self.childId, "v-wormFire", segmentOrder[i], args.target)
    util.run(args.fireInterval, function() end)
  end
  
  return true
end

-- param size
-- param numPoints
-- param speed
-- param tolerance
-- param center
function v_wormFigure8(args, board, _, dt)
  -- Makes the worm move in a simple figure-8 pattern--more specifically, a lemniscate curve.
  -- size is how far out the bulbs of the figure 8 extend
  -- period is the amount of time the worm takes to complete one figure-8 loop assuming it gets to each point within the
  -- next time step. (unused for now)
  -- speed is how fast to move to the next point
  -- tolerance is the maximum distance allowed for the worm to be considered "at" a target position.
  -- center is the center of the figure 8.
  local center = args.center  -- cache so that a dynamically-changing reference does not mess up the center
  local ticker = 0
  local nextPos
  
  while true do
    -- Get the next position that is out of reach of the worm.
    repeat
      nextPos = vec2.add(center, v_figure8(args.size, args.numPoints, ticker))
      ticker = (ticker + 1) % args.numPoints
    until world.magnitude(nextPos, mcontroller.position()) > args.tolerance
    
    world.debugPoint(nextPos, "green")
    
    -- Fly to position
    v_flyToPos(nextPos, args.speed, 99999999, args.tolerance)
  end
end