require "/scripts/util.lua"
require "/scripts/vec2.lua"
require "/scripts/poly.lua"
require "/scripts/actions/crawling.lua"

-- param minRange
-- param maxRange
-- param position
-- param speed
-- param controlForce
-- param correctionStepSize (optional) - Parameter specifying the precision to which the target angle should be 
--     corrected (in cases where the monster is moving away from its target) to avoid getting stuck in a wall.
-- param avoidSurfaces (optional) - True if the entity should avoid getting stuck in surfaces. Do not use because it's
--     broken
function v_rangedFlyApproach(args, board, _, dt)
  local controlForce = args.controlForce or mcontroller.baseParameters().airForce

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
          mcontroller.controlApproachVelocity(vec2.mul(direction, args.speed), controlForce)
          mcontroller.controlFace(util.toDirection(direction[1]))
        end
      else
        local direction = vec2.rotate(direction, math.pi)
        mcontroller.controlApproachVelocity(vec2.mul(direction, args.speed), controlForce)
        mcontroller.controlFace(util.toDirection(direction[1]))
      end
    elseif distance > args.maxRange then
      -- Fly toward player
      mcontroller.controlApproachVelocity(vec2.mul(direction, args.speed), controlForce)
      mcontroller.controlFace(util.toDirection(direction[1]))
    else
      -- Stop
      mcontroller.controlApproachVelocity({0, 0}, controlForce)
    end
    coroutine.yield()
  end
end

-- param position1
-- param position2
-- param speed
-- param tolerance
function v_flyToNearerPosition(args, board)
  if not args.position1 then
    sb.logInfo("args.position1 not defined. Failing")
    return false
  end
  
  if not args.position2 then
    sb.logInfo("args.position2 not defined. Failing")
    return false
  end
  
  if not args.tolerance then
    sb.logInfo("args.tolerance not defined. Failing")
    return false
  end
  
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