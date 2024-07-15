require "/scripts/vec2.lua"
require "/scripts/v-behavior.lua"

-- param position1
-- param position2
-- param center
-- param offset1
-- param offset2
-- param entityTypes
-- param orderBy
-- param withoutEntity
-- output entity
-- output list
function v_queryEntityRect(args, board)
  local rq = vBehavior.requireArgsGen("v_queryEntityRect", args)

  if not rq{"entityTypes", "withoutEntity"} then
    return false
  end

  local position1
  if not args.position1 then
    if not rq{"center", "offset1"} then return false end
    
    position1 = vec2.add(args.center, args.offset1)
  else
    position1 = args.position1
  end
  
  local position2
  if not args.position2 then
    if not rq{"center", "offset2"} then return false end
    
    position2 = vec2.add(args.center, args.offset2)
  else
    position2 = args.position2
  end

  local queryArgs = {
    includedTypes = args.entityTypes,
    order = args.orderBy,
    withoutEntityId = args.withoutEntity
  }
  local nearEntities = world.entityQuery(position1, position2, queryArgs)
  if #nearEntities > 0 then
    return true, {entity = nearEntities[1], list = nearEntities}
  end

  return false
end