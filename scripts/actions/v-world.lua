require "/scripts/v-behavior.lua"
require "/scripts/vec2.lua"

-- param uniqueId
-- output position
function v_getUniqueEntityPosition(args, board)
  local rq = vBehavior.requireArgsGen("v_getUniqueEntityPosition", args)

  if not rq{"uniqueId"} then return false end

  local entityId = world.loadUniqueEntity(args.uniqueId)

  if entityId and world.entityExists(entityId) then
    return true, {position = world.entityPosition(entityId)}
  else
    sb.logWarn("Failed to load unique entity '%s'", args.uniqueId)
  end

  return false
end

-- param name
-- param position
-- param offset
-- param overrides
-- output vehicleId
function v_spawnVehicle(args, board)
  local rq = vBehavior.requireArgsGen("v_spawnVehicle", args)

  if not rq{"name", "position"} then return false end

  local pos = args.offset and vec2.add(args.position, args.offset) or args.position

  local entityId = world.spawnVehicle(args.name, pos, args.overrides)

  return true, {vehicleId = entityId}
end

-- A more featureful version of sendEntityMessage that resolves references to blackboard variables.
-- param entity
-- param message
-- param arguments (optional)
function v_sendEntityMessage(args, board)
  local rq = vBehavior.requireArgsGen("v_sendEntityMessage", args)

  if not rq{"entity", "message"} then return false end

  local arguments = args.arguments or {}
  world.sendEntityMessage(args.entity, args.message, table.unpack(vBehavior.resolveRefs(arguments, board)))

  return true
end

function v_entityVelocity(args, board)
  local rq = vBehavior.requireArgsGen("v_entityVelocity", args)

  if not rq{"entity"} then return false end

  if not world.entityExists(args.entity) then return false end

  local velocity = world.entityVelocity(args.entity)

  return true, {velocity = velocity, magnitude = vec2.mag(velocity)}
end

-- param position
-- param maxCorrection
-- param useBoundBox (optional)
-- param boundBoxPadding (optional)
function v_resolvePolyCollision(args, board)
  if not vBehavior.requireArgs("v_resolvePolyCollision", args, {"position", "maxCorrection"}) then
    return false
  end

  local collisionPoly
  if args.useBoundBox then
    local boundBox = mcontroller.boundBox()
    boundBox = rect.pad(boundBox, args.boundBoxPadding or 0.25)
    collisionPoly = {
      rect.ll(boundBox),
      rect.lr(boundBox),
      rect.ur(boundBox),
      rect.ul(boundBox)
    }
  else
    collisionPoly = mcontroller.collisionPoly()
  end
  local pos = world.resolvePolyCollision(collisionPoly, args.position, args.maxCorrection)
  if not pos then
    world.debugPoint(args.position, "red")
    return false
  end

  world.debugLine(args.position, pos, "green")

  return true, {result = pos}
end

-- param center
-- param rayCount
-- param minRaycastLength
-- param maxRaycastLength
-- param collisionSet
function v_radialRaycast(args)
  if not vBehavior.requireArgs("v_radialRaycast", args, {"center", "rayCount", "maxRaycastLength"}) then
    return false
  end

  return true, {result = vWorld.radialRaycast{
    raycastCount = args.rayCount,
    center = args.center,
    minRaycastLength = args.minRaycastLength,
    maxRaycastLength = args.maxRaycastLength,
    collisionSet = args.collisionSet
  }}
end