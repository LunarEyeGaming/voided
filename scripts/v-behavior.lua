require "/scripts/behavior/bdata.lua"

vBehavior = {}

-- TODO: This code is stupid and dumb. Make it use var-args at the end instead.
---Generates a function that checks if arguments with names `names` are all defined in `args`, sending a warning to the
---log if any of them are not defined. `nodeName` is used to help identify the node from which an argument is undefined.
---The inner function returns whether or not all of the arguments are defined.
---
---@param nodeName string the name of the node to display in any warning messages
---@param args table the set of arguments to check
---@return function rq a function that, when called with a string list `names`, returns true if all values with keys
---`names` are defined in `args`, false otherwise (logging a warning in this case)
function vBehavior.requireArgsGen(nodeName, args)
  -- Return the function
  return function(names)
    -- For each name in names...
    for _, name in ipairs(names) do
      -- If the argument is not defined...
      if args[name] == nil then
        -- Send a warning message and return false.
        sb.logWarn("%s: Argument '%s' not defined.", nodeName, name)
        return false
      end
    end

    return true
  end
end

-- Coroutine function that waits until it receives <count> notifications of the specified type (default is 1).
-- self.notifications must be defined and must work correctly.
function vBehavior.awaitNotification(type_, count)
  count = count or 1
  local notifications = {}
  while count > 0 do
    local i = 1
    while i <= #self.notifications do
      local notification = self.notifications[i]
      if notification.type == type_ then
        --sb.logInfo("self.notifications = %s, i = %s", self.notifications, i)
        table.remove(self.notifications, i)
        table.insert(notifications, notification)

        count = count - 1
      else
        i = i + 1
      end
    end
    coroutine.yield()
  end

  return notifications
end

---Flies to a given `position` with a provided `speed` and `tolerance` as well as `controlForce`, rotating "body" toward
---the target.
---@param pos Vec2F the position to fly to
---@param speed number the speed at which to fly to the position
---@param controlForce number the control force to use when flying to the position
---@param tolerance number the maximum distance necessary to consider the entity "at" the target position
function vBehavior.rotatedFlyToPosition(pos, speed, controlForce, tolerance)
  local atPos

  while not atPos do
    atPos = vBehavior.rotatedFlyToPositionTick(pos, speed, controlForce, tolerance)

    coroutine.yield(nil)
  end
end

---Similar to `vBehavior.rotatedFlyToPosition`, except it flies to the position for one tick and returns `true` if the
---entity is within `tolerance` (in both axes) of the target position, `false` otherwise.
---@param pos Vec2F the position to fly to
---@param speed number the speed at which to fly to the position
---@param controlForce number the control force to use when flying to the position
---@param tolerance number the maximum distance necessary to consider the entity "at" the target position
function vBehavior.rotatedFlyToPositionTick(pos, speed, controlForce, tolerance)
  -- Approach velocity necessary to reach the target position
  local distance = world.distance(pos, mcontroller.position())
  mcontroller.controlApproachVelocity(vec2.mul(vec2.norm(distance), speed), controlForce)

  -- Rotate to current velocity
  local rotation = vec2.angle(mcontroller.velocity())
  mcontroller.setRotation(rotation)
  animator.resetTransformationGroup("body")
  animator.rotateTransformationGroup("body", rotation)

  mcontroller.controlFace(1)

  return math.abs(distance[1]) < tolerance and math.abs(distance[2]) < tolerance
end

---Resolve references to blackboard variables in a table and its nested tables. References are denoted with
---`$<type>:<var>`
---@param table_ table A table potentially containing references to blackboard variables
---@param board any The blackboard to use
---@return table resolved `table_` with all references resolved
function vBehavior.resolveRefs(table_, board)
  local newTable = {}
  for k, v in pairs(table_) do
    if type(v) == "table" then
      newTable[k] = vBehavior.resolveRefs(v, board)
    elseif type(v) == "string" and voidedUtil.strStartsWith(v, "$") then
      local ref = util.split(v:sub(2, #v), ":")
      newTable[k] = board:get(ref[1], ref[2])  -- Lookup variable name on the blackboard
    else
      newTable[k] = v
    end
  end
  return newTable
end

---Returns a table with results for the nine behavior tree data types.
---@param value any
---@return table
function vBehavior.anyTypeTable(value)
  results = {}
  for _, dataType in pairs(ListTypes) do
    results[dataType] = value
  end
  return results
end