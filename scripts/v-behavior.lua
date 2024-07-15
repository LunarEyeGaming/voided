vBehavior = {}

--[[
  Generates a function that checks if arguments with names `names` are all defined in `args`, sending a warning to the
  log if any of them are not defined. `nodeName` is used to help identify the node from which an argument is undefined.
  The inner function returns whether or not all of the arguments are defined.
  
  param (string) nodeName: the name of the node to display in any warning messages
  param (table) args: the set of arguments to check
  param (string list) names: the names of the arguments that are required
  returns: a function that, when called with a string list `names`, returns true if all values with keys `names` are
  defined in `args`, false otherwise (logging a warning in this case)
]]
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