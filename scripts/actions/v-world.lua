require "/scripts/v-behavior.lua"

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