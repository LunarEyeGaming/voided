vBehavior = {}

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