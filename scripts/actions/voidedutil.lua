require "/scripts/behavior/bdata.lua"
require "/scripts/util.lua"
require "/scripts/v-behavior.lua"

-- param list
-- param index
-- output entity
-- output number
-- output position
-- output vector
function v_listGet2(args, board)
  local list = args.list or jarray()
  local value = list[args.index]
  if value == nil then return false end
  return true, vBehavior.anyTypeTable(value)
end

-- param type
function v_receivedNotification2(args, board)
  if args.type == nil then return false end

  for i,notification in pairs(self.notifications) do
    if notification.type == args.type then
      table.remove(self.notifications, i)
      return true, {data = notification}
    end
  end
  return false
end

-- param entity
-- param type
-- param data
function v_sendNotification2(args, board)
  if args.type == nil or args.entity == nil then return false end

  notification = vBehavior.resolveRefs(args.data, board)
  notification.type = args.type

  world.callScriptedEntity(args.entity, "notify", notification)
  return true
end

-- Set data of the specified key in a JSON object to value.
-- param object
-- param key
-- Refer to ListTypes in bdata.lua for info on the types of values that can be inserted.
-- output object

function v_setJsonKey(args, board)
  if args.key == nil then return false end
  local newObject = args.object ~= nil and copy(args.object) or {}
  for _, dataType in pairs(ListTypes) do
    if args[dataType] then
      newObject[args.key] = args[dataType]
      return true, {object = newObject}
    end
  end
  return false, {object = object}
end

-- Remove a key from a JSON object
-- param object
-- param key
-- output object

function v_removeJsonKey(args, board)
  if args.key == nil or args.object == nil then return false end
  local newObject = copy(args.object)
  newObject[args.key] = nil
  return true, {object = newObject}
end

-- Get the value of a specified key in a JSON object.
-- param object
-- param key
-- output value

function v_getJsonKey(args, board)
  local object = args.object or {}
  local value = object[args.key]
  if value == nil then return false end
  return true, vBehavior.anyTypeTable(value)
end

-- param xRadius
-- param yRadius
-- param angle
-- output result

function v_ellipsePoint(args, board)
  if args.xRadius == nil or args.yRadius == nil or args.angle == nil then return false end
  if args.useDegrees then
    args.angle = util.toRadians(args.angle)
  end
  return true, {result = {args.xRadius * math.cos(args.angle), args.yRadius * math.sin(args.angle)}}
end

-- param msg
-- param formatArgs
function v_logInfo(args, board)
  if args.formatArgs and next(args.formatArgs) ~= nil then  -- If args.formatArgs is defined and is not empty
    sb.logInfo(args.msg, table.unpack(vBehavior.resolveRefs(args.formatArgs, board)))
  else
    sb.logInfo(args.msg)
  end

  return true
end

-- Looks up a board variable using a formatted string.
-- param type
-- param formatKeyName
-- param formatArgs
-- output result
function v_dynamicRefLookup(args, board)
  local rq = vBehavior.requireArgsGen("v_dynamicRefLookup", args)

  if not rq{"formatKeyName", "formatArgs"} then return false end

  local keyName = string.format(args.formatKeyName, table.unpack(vBehavior.resolveRefs(args.formatArgs, board)))

  return true, vBehavior.anyTypeTable(board:get(args.type, keyName))
end

-- param targetList
-- param list
-- param entity
-- param number
-- param position
-- param vec2
-- param table
-- param json
-- param string
-- param bool
function v_listRemove(args, board)
  if args.targetList == nil then return false end

  local list = copy(args.targetList)

  -- Find the right type of item to remove.
  for _,type in pairs(ListTypes) do
    if args[type] then
      -- Try to remove the item by searching for it.
      for i, v in ipairs(list) do
        if vUtil.deepEquals(args[type], v) then
          -- Remove the item
          table.remove(list, i)
          -- Return success.
          return true, {list = list}
        end
      end
    end
  end

  -- Removing the list failed.
  return false
end

-- Returns the angle and direction.
-- param angle
-- output angle
-- output direction
function v_angleAndDirection(args)
  local rq = vBehavior.requireArgsGen("v_angleAndDirection", args)

  if not rq{"angle"} then return false end

  local angle = args.angle

  local adjustedAngle
  local direction
  if math.pi / 2 < angle and angle < 3 * math.pi / 2 then
    adjustedAngle = math.pi - angle
    direction = -1
  else
    adjustedAngle = angle
    direction = 1
  end

  return true, {angle = adjustedAngle, direction = direction}
end