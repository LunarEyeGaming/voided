---Ticker class. Allows for the simple addition of periodic function calls.
---@class VTicker
---@field _intervals table
VTicker = {}

---Creates a new VTicker instance.
---@return VTicker
function VTicker:new()
  local instance = {
    _intervals = {}
  }

  setmetatable(instance, self)
  self.__index = self

  return instance
end

---Adds a function `func` to be periodically called every `duration` seconds.
---@param duration number
---@param func fun()
function VTicker:addInterval(duration, func)
  table.insert(self._intervals, {duration = duration, func = func, timer = duration})
end

---Processes the current intervals for one tick
---@param dt number
function VTicker:update(dt)
  for _, interval in ipairs(self._intervals) do
    interval.timer = interval.timer - dt

    if interval.timer <= 0 then
      interval.func()

      interval.timer = interval.duration
    end
  end
end

local ticker = VTicker:new()

---Global instance of a ticker. Included for convenience. Use only if you are confident that only one script in a given
---contect will need a ticker.
vTime = {}

---Adds a function `func` to be periodically called every `duration` seconds.
---@param duration number
---@param func fun()
function vTime.addInterval(duration, func)
  ticker:addInterval(duration, func)
end

---Processes the current intervals for one tick
---@param dt number
function vTime.update(dt)
  ticker:update(dt)
end