require "/scripts/vec2.lua"

require "/scripts/v-behavior.lua"

-- Returns an adjusted version of a position in relation to a target. The position is adjusted such that the controller
-- can reach it without going through blocks.
-- param flightOffset - the position to fly to relative to the given entity position.
-- param entityPosition - the position of the target entity
-- param maxPolyResolution - the maximum distance to resolve poly collisions
-- param collisionKinds - (optional) the kinds of collision to test
-- output position
function v_giveBestPosition(args, board)
  if not vBehavior.requireArgs("v_giveBestPosition", args, {"flightOffset", "entityPosition", "maxPolyResolution"}) then
    return false
  end

  local flightPosition = vec2.add(args.entityPosition, args.flightOffset)
  local collidePoint = world.lineCollision(args.entityPosition, flightPosition, args.collisionKinds)

  local newPosition
  if collidePoint then
    local resolvedPoint = world.resolvePolyCollision(mcontroller.collisionPoly(), collidePoint, args.maxPolyResolution)

    if not resolvedPoint then
      error(string.format("Failed to resolve collision. Original position: (%s, %s), maxCorrection: %s", collidePoint[1], collidePoint[2], args.maxPolyResolution))
    end

    newPosition = resolvedPoint
  else
    newPosition = flightPosition
  end

  world.debugPoint(newPosition, "green")

  return true, {result = newPosition}
end

function v_getAirBurstTTL(args, board)
  if not vBehavior.requireArgs("v_getAirBurstTTL", args, {"startPos", "endPos", "speed"}) then
    return false
  end

  local mag = world.magnitude(args.startPos, args.endPos)
  local ttl = mag / args.speed

  return true, {time = ttl}
end