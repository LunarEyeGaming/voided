require "/scripts/v-behavior.lua"

-- param gridDimensions
-- param coordDelimiter
-- param uniqueIdPrefix
-- param boardVarPrefix
function v_fetchPositions(args, board)
  local rq = vBehavior.requireArgsGen("v_fetchPositions", args)

  if not rq{"gridDimensions", "coordDelimiter", "uniqueIdPrefix", "boardVarPrefix"} then return false end

  -- For each coordinate in the grid...
  for x = 1, args.gridDimensions[1] do
    for y = 1, args.gridDimensions[2] do
      local uniqueId = string.format("%s%d%s%d", args.uniqueIdPrefix, x, args.coordDelimiter, y)
      local boardVar = string.format("%s%d%s%d", args.boardVarPrefix, x, args.coordDelimiter, y)

      local entityId = world.loadUniqueEntity(uniqueId)

      if not entityId or not world.entityExists(entityId) then
        sb.logWarn("v_fetchPositions: Could not find position with unique ID '%s'", entityId)
        return false
      end

      board:setPosition(boardVar, world.entityPosition(entityId))
    end
  end

  return true
end

-- output entityIds
function v_getChildren()
  return true, {entityIds = world.callScriptedEntity(self.childId, "getChildren")}
end