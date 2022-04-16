require "/scripts/behavior/bdata.lua"
require "/scripts/voidedutil.lua"

function _anyTypeTable(value)
  results = {}
  for _, dataType in pairs(ListTypes) do
    results[dataType] = value
  end
  return results
end

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
  return true, _anyTypeTable(value)
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

-- Sets data of the specified key in a JSON object to value.
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

-- Removes a key from a JSON object
-- param object
-- param key
-- output object

function v_removeJsonKey(args, board)
  if args.key == nil or args.object == nil then return false end
  local newObject = copy(args.object)
  newObject[args.key] = nil
  return true, {object = newObject}
end

-- Gets the value of a specified key in a JSON object.
-- param object
-- param key
-- output value

function v_getJsonKey(args, board)
  local object = args.object or {}
  local value = object[args.key]
  if value == nil then return false end
  return true, _anyTypeTable(value)
end

-- param xRadius
-- param yRadius
-- param angle
-- output result

function v_ellipsePoint(args, board)
  if args.xRadius == nil or args.yRadius == nil or args.angle == nil then return false end
  return true, {result = {args.xRadius * math.cos(args.angle), args.yRadius * math.sin(args.angle)}}
end