require "/scripts/util.lua"
require "/scripts/vec2.lua"
require "/scripts/poly.lua"
require "/scripts/actions/crawling.lua"
require "/scripts/actions/projectiles.lua"
require "/scripts/v-behavior.lua"
require "/scripts/v-movement.lua"
require "/scripts/v-attack.lua"

-- param minRange
-- param maxRange
-- param position
-- param speed
-- param controlForce
-- param correctionStepSize (optional) - Parameter specifying the precision to which the target angle should be
--     corrected (in cases where the monster is moving away from its target) to avoid getting stuck in a wall.
-- param avoidSurfaces (optional) - True if the entity should avoid getting stuck in surfaces. Do not use because it's
--     broken
-- param faceDirection (optional) - True if the entity should face the direction in which it is flying, false otherwise.
--     True by default
function v_rangedFlyApproach(args, board, _, dt)
  local rq = vBehavior.requireArgsGen("v_rangedFlyApproach", args)

  if not rq{"minRange", "maxRange", "position", "speed"} then return false end

  local controlForce = args.controlForce or mcontroller.baseParameters().airForce
  local faceDirection
  if args.faceDirection == nil then
    faceDirection = true
  else
    faceDirection = args.faceDirection
  end

  local flyInDirection = function(direction)
    mcontroller.controlApproachVelocity(vec2.mul(direction, args.speed), controlForce)

    -- Face the direction in which the entity is flying if told to do so.
    if faceDirection then
      mcontroller.controlFace(util.toDirection(direction[1]))
    end
  end

  while true do
    -- Fly through platforms
    mcontroller.controlDown()

    local direction = vec2.norm(world.distance(args.position, mcontroller.position()))
    local distance = world.magnitude(args.position, mcontroller.position())
    if distance < args.minRange then
      -- Fly away from the player
      if args.avoidSurfaces then
        -- Avoid surfaces
        local angle = vec2.angle(direction)
        local fleeAngle = _getFleeAngle(angle, args.speed, args.correctionStepSize, dt)
        if fleeAngle then
          local direction = vec2.rotate(direction, fleeAngle)
          flyInDirection(direction)
        end
      else
        local direction = vec2.rotate(direction, math.pi)
        flyInDirection(direction)
      end
    elseif distance > args.maxRange then
      -- Fly toward player
      flyInDirection(direction)
    else
      -- Stop
      mcontroller.controlApproachVelocity({0, 0}, controlForce)
    end
    coroutine.yield()
  end
end

-- param position1
-- param position2
-- param speed (optional)
-- param tolerance
function v_flyToNearerPosition(args, board)
  local rq = vBehavior.requireArgsGen("v_flyToNearerPosition", args)

  if not rq{"position1", "position2", "tolerance"} then return false end

  while true do
    local speed = args.speed or mcontroller.baseParameters().flySpeed

    local position, distance = _getCloserPositionAndMagnitude(mcontroller.position(), args.position1, args.position2)
    if distance <= args.tolerance then break end

    local toTarget = vec2.norm(world.distance(position, mcontroller.position()))
    mcontroller.controlApproachVelocity(vec2.mul(toTarget, speed), mcontroller.baseParameters().airForce)
    mcontroller.controlFace(util.toDirection(toTarget[1]))
    mcontroller.controlDown()

    coroutine.yield(nil, {vector = toTarget})
  end

  mcontroller.controlFly({0,0})
  return true
end

-- param position
-- param speed
-- param controlForce
-- param tolerance
function v_flyToPositionNoFlip(args)
  local rq = vBehavior.requireArgsGen("v_flyToPositionNoFlip", args)
  if not rq{"position"} then return false end

  vMovementA.flyToPosition(args.position, args.speed, args.controlForce, args.tolerance)

  return true
end

-- Variant of the crawl() behavior node from vanilla that allows for a configurable "testDistance," which determines
-- how far from the monster's collision poly the ground has to be, as well as a way to configure the control force that
-- keeps the monster from slipping off a ledge.
-- param direction
-- param run
-- param testDistance
-- param stickForce
-- output headingDirection
-- output headingAngle
function v_crawl(args, board)
  local bounds = mcontroller.boundBox()
  local size = bounds[3] - bounds[1]

  local groundDirection = findGroundDirection(args.testDistance)
  if not groundDirection then return false end

  local baseParameters = mcontroller.baseParameters()
  local moveSpeed = args.run and baseParameters.runSpeed or baseParameters.walkSpeed

  local headingAngle
  while true do
    local groundDirection = findGroundDirection(args.testDistance)

    if groundDirection then
      if not headingAngle then
        headingAngle = (math.atan(groundDirection[2], groundDirection[1]) + math.pi / 2) % (math.pi * 2)
      end

      if args.direction == nil then return false end

      headingAngle = adjustCornerHeading(headingAngle, args.direction)

      local groundAngle = headingAngle - (math.pi / 2)
      mcontroller.controlApproachVelocity(vec2.withAngle(groundAngle, moveSpeed), args.stickForce)

      local moveDirection = vec2.rotate({args.direction, 0}, headingAngle)
      mcontroller.controlApproachVelocityAlongAngle(math.atan(moveDirection[2], moveDirection[1]), moveSpeed, 2000)

      mcontroller.controlParameters({
        gravityEnabled = false
      })

      coroutine.yield(nil, {headingDirection = vec2.withAngle(headingAngle), headingAngle = headingAngle})
    else
      break
    end
  end

  return false, {headingDirection = {1, 0}, forwardAngle = 0}
end

-- param stopForce
function v_stop(args)
  local rq = vBehavior.requireArgsGen("v_stop", args)
  if not rq{"stopForce"} then return false end

  -- Slow down until the entity has stopped moving.
  while vec2.mag(mcontroller.velocity()) > 0 do
    mcontroller.controlApproachVelocity({0, 0}, args.stopForce)
    coroutine.yield()
  end

  return true
end

-- param useSticky
-- param explosionProjectile
-- param explosionConfig
-- param explosionDistance
-- param speedThreshold
-- param target
function v_impactAction(args, board)
  local collisionCond
  if args.useSticky then
    collisionCond = mcontroller.isCollisionStuck()
    mcontroller.controlParameters({stickyCollision = true})
  else
    collisionCond = mcontroller.isColliding()
  end

  local explosionConfig = copy(args.explosionConfig)
  explosionConfig.power = vAttack.scaledPower(explosionConfig.power or 10)

  local ownPos = mcontroller.position()

  if (collisionCond or world.magnitude(ownPos, world.entityPosition(args.target)) < args.explosionDistance)
  and vec2.mag(mcontroller.velocity()) > args.speedThreshold then
    world.spawnProjectile(args.explosionProjectile, ownPos, entity.id(), {0, 0}, false, explosionConfig)
    status.setResourcePercentage("health", 0.0)
    return true
  end

  return false
end

-- param target
function v_stickyHopApproach(args, _, _, dt)
  local args2 = {
    rayCount = 40,
    minRaycastLength = 5,
    maxRaycastLength = 50,
    hopSpeed = 60,
    postHopDelay = 0.1,
    gravityMultiplier = 1.5
  }

  local targetCandidates = {}
  local targetPos = world.entityPosition(args.target)

  for i = 0, args2.rayCount - 1 do
    local angle = 2 * math.pi * i / args2.rayCount

    -- Attempt raycast
    local raycast = world.lineCollision(targetPos, vec2.add(targetPos, vec2.withAngle(angle, args2.maxRaycastLength)))
    -- If successful and the distance from the target to the raycast exceeds args.minRaycastLength...
    if raycast and world.magnitude(targetPos, raycast) >= args2.minRaycastLength then
      table.insert(targetCandidates, raycast)
    end
  end

  local ownPos = mcontroller.position()

  -- Find a valid hop position and get the corresponding velocity, accounting for gravity, upon success.
  local hopPos, hopVelocity
  -- Shuffle the list of positions.
  shuffle(targetCandidates)

  -- For each position...
  for _, pos in ipairs(targetCandidates) do
    -- If the position is in line of sight...
    if not world.lineCollision(ownPos, pos) then
      local success
      -- Get the hopping velocity, accounting for gravity.
      hopVelocity, success = util.aimVector(world.distance(pos, ownPos), args2.hopSpeed, args2.gravityMultiplier, false)

      world.debugLine(ownPos, pos, success and "green" or "red")

      -- If successful...
      if success then
        hopPos = pos  -- Make that the hop position.
        break  -- Exit the loop.
      end
    end
  end

  -- If no valid hop position was found...
  if not hopPos then
    local success
    -- Use the first position listed as it is effectively a random position due to the shuffling.
    local testPos = targetCandidates[1]

    -- If it is actually defined...
    if testPos then
      -- Get the hopping velocity, accounting for gravity.
      hopVelocity, success = util.aimVector(world.distance(testPos, ownPos), args2.hopSpeed, args2.gravityMultiplier, false)

      -- If successful...
      if success then
        hopPos = testPos  -- Use the test position.
      end
    end
  end

  -- If no valid hop position was found still...
  if not hopPos then
    -- Hop directly toward the target
    hopPos = targetPos
    -- Get the hopping velocity, accounting for gravity.
    hopVelocity = util.aimVector(world.distance(hopPos, ownPos), args2.hopSpeed, args2.gravityMultiplier, false)
  end

  -- y = y0 + vy * t - 1/2 * a * t^2
  -- y = vy * t - 1/2 * g * t^2
  -- -1/2 * g * t^2 + vy * t - y = 0
  -- t = (-vy +/- sqrt(vy^2 - 4 * -1/2 * g * -y))
  -- local arrivalTime =

  local arc
  do
    arc = {}
    local toTarget = world.distance(hopPos, mcontroller.position())
    local aimVector = vec2.norm(util.aimVector(toTarget, args2.hopSpeed, args2.gravityMultiplier, false))
    -- Simulate the arc
    local velocity = vec2.mul(aimVector, args2.hopSpeed)
    local startArc = mcontroller.position()
    local x = 0
    while x < math.abs(toTarget[1]) do
      local time = x / math.abs(velocity[1])
      local yVel = velocity[2] - (args2.gravityMultiplier * world.gravity(mcontroller.position()) * time)
      local step = vec2.add({util.toDirection(aimVector[1]) * x, ((velocity[2] + yVel) / 2) * time}, mcontroller.position())

      startArc = step
      table.insert(arc, startArc)
      local arcVector = vec2.norm({velocity[1], yVel})
      x = x + math.abs(arcVector[1])
    end
  end

  -- Jump
  mcontroller.setVelocity(hopVelocity)

  -- Wait for a brief time before doing any tests.
  util.run(args2.postHopDelay, function() end)

  local testRect = rect.pad(mcontroller.boundBox(), 0.25)

  -- Wait until the entity has attached to something or has reached its destination (as a more reliable check).
  while not world.rectCollision(rect.translate(testRect, mcontroller.position()))
  and world.magnitude(hopPos, mcontroller.position()) > 4 do
    world.debugPoint(hopPos, "green")
    for i = 1, #arc - 1 do
      world.debugLine(arc[i], arc[i + 1], "green")
    end
    coroutine.yield()
  end

  -- mcontroller.setVelocity({0, 0})

  return true
end

function _correctAngle(angle, speed, step, dt)
  local collisionPoly = mcontroller.collisionBody()
  local pos = mcontroller.position()
  local offset = vec2.rotate({speed * dt, 0}, angle)
  local angleOffset = 0
  while world.polyCollision(poly.translate(collisionPoly, offset)) do
    angleOffset = angleOffset + step
    offset = vec2.rotate({speed * dt, 0}, angle + angleOffset)
    if angleOffset > 2 * math.pi then return end
  end
  return angle + angleOffset
end

-- This makes enemies very unpredictable for some reason.
function _getFleeAngle(targetAngle, speed, step, dt)
  local initialFleeAngle = util.wrapAngle(targetAngle + math.pi)
  -- fleeAngle1 will be evaluated. If it ends up making it approach the target, simply return the angle correction in
  -- the other direction.
  local fleeAngle1 = _correctAngle(initialFleeAngle, speed, step, dt)
  if util.wrapAngle(math.abs(fleeAngle1 - targetAngle)) < math.pi / 2 then
    return _correctAngle(initialFleeAngle, speed, -step, dt)
  end

  return fleeAngle1
end

function _getCloserPositionAndMagnitude(position, target1, target2)
  local distance1 = world.magnitude(position, target1)
  local distance2 = world.magnitude(position, target2)
  if distance1 < distance2 then
    return target1, distance1
  else
    return target2, distance2
  end
end