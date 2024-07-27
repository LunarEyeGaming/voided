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