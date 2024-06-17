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