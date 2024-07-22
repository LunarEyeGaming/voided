require "/scripts/behavior/bdata.lua"
require "/scripts/util.lua"
require "/scripts/voidedutil.lua"
require "/scripts/v-behavior.lua"

function _anyTypeTable(value)
  results = {}
  for _, dataType in pairs(ListTypes) do
    results[dataType] = value
  end
  return results
end

function _resolveRefs(table_, board)
  --[[
    Resolve references to blackboard variables in a table and its nested tables. References are denoted with $<type>:<var>

    param table_: A table potentially containing references to blackboard variables
    param board: The blackboard to use
    return: table_ with all references resolved
  ]]
  local newTable = {}
  for k, v in pairs(table_) do
    if type(v) == "table" then
      newTable[k] = _resolveRefs(v, board)
    elseif type(v) == "string" and voidedUtil.strStartsWith(v, "$") then
      local ref = util.split(v:sub(2, #v), ":")
      newTable[k] = board:get(ref[1], ref[2])  -- Lookup variable name on the blackboard
    else
      newTable[k] = v
    end
  end
  return newTable
end

--[[
  Returns whether or not two arguments a and b are equal, even if they are tables. Recursive tables are not supported
  and can result in infinite recursion.

  param a: the first value to compare
  param b: the second value to compare
]]
function _deepEquals(a, b)
  -- If both values are tables...
  if type(a) == "table" and type(b) == "table" then
    -- For each key-value pair in `a`...
    for k, va in pairs(a) do
      local vb = b[k]

      -- If va and vb do not match...
      if not _deepEquals(va, vb) then
        return false
      end
    end

    -- Return true here as this means that all entries of a and b are structurally identical.
    return true
  else
    -- Return whether or not they are equal.
    return a == b
  end
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

-- param entity
-- param type
-- param data
function v_sendNotification2(args, board)
  if args.type == nil or args.entity == nil then return false end

  notification = _resolveRefs(args.data, board)
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
  return true, _anyTypeTable(value)
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
    sb.logInfo(args.msg, table.unpack(_resolveRefs(args.formatArgs, board)))
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

  local keyName = string.format(args.formatKeyName, table.unpack(_resolveRefs(args.formatArgs, board)))

  return true, _anyTypeTable(board:get(args.type, keyName))
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
        if _deepEquals(args[type], v) then
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