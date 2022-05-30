require "/scripts/util.lua"
require "/scripts/vec2.lua"
require "/scripts/poly.lua"

-- param minRange
-- param maxRange
-- param position
-- param speed
-- param controlForce
-- param correctionStepSize - Parameter specifying the precision to which the target angle should be corrected (in cases where the monster is moving away from its target) to avoid getting stuck in a wall.
function v_rangedFlyApproach(args, board, _, dt)
  while true do
    -- Fly through platforms
    mcontroller.controlDown()

    local direction = vec2.norm(world.distance(args.position, mcontroller.position()))
    local distance = world.magnitude(args.position, mcontroller.position())
    if distance < args.minRange then
      -- Fly away from the player
      -- local angle = vec2.angle(direction)
      -- local fleeAngle = _getFleeAngle(angle, args.speed, args.correctionStepSize, dt)
      -- if fleeAngle then
        -- local direction = vec2.rotate(direction, fleeAngle)
        -- mcontroller.controlApproachVelocity(vec2.mul(direction, args.speed), args.controlForce)
        -- mcontroller.controlFace(util.toDirection(direction[1]))
      -- end
      local direction = vec2.rotate(direction, math.pi)
      mcontroller.controlApproachVelocity(vec2.mul(direction, args.speed), args.controlForce)
      mcontroller.controlFace(util.toDirection(direction[1]))
    elseif distance > args.maxRange then
      -- Fly toward player
      mcontroller.controlApproachVelocity(vec2.mul(direction, args.speed), args.controlForce)
      mcontroller.controlFace(util.toDirection(direction[1]))
    else
      -- Stop
      mcontroller.controlApproachVelocity({0, 0}, args.controlForce)
    end
    coroutine.yield()
  end
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

function _getFleeAngle(targetAngle, speed, step, dt)
  local initialFleeAngle = util.wrapAngle(targetAngle + math.pi)
  -- fleeAngle1 will be evaluated. If it ends up making it approach the target, simply return the angle correction in the other direction.
  local fleeAngle1 = _correctAngle(initialFleeAngle, speed, step, dt)
  if util.wrapAngle(math.abs(fleeAngle1 - targetAngle)) < math.pi / 2 then
    return _correctAngle(initialFleeAngle, speed, -step, dt)
  end
  return fleeAngle1
end