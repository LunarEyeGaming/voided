---Ticker class. Allows for the simple addition of periodic and delayed function calls.
---@class VTicker
---@field _intervals table
---@field _delayedTasks table
VTicker = {}

---Creates a new VTicker instance.
---@return VTicker
function VTicker:new()
  local instance = {
    _intervals = {},
    _delayedTasks = {}
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

---Adds a delayed task. These tasks are called on the next call to the `update` method or after `ticks` calls to
---`update`.
---@param task fun() | {ticks: number, func: fun()}
function VTicker:addDelayedTask(task)
  if type(task) == "table" then
    table.insert(self._delayedTasks, task)
  else
    table.insert(self._delayedTasks, {ticks = 1, func = task})
  end
end

---Processes the current intervals for one tick
---@param dt number
function VTicker:update(dt)
  for _, interval in ipairs(self._intervals) do
    interval.timer = interval.timer - dt

    if interval.timer <= 0 then
      -- self._inIntervalFunc = true
      interval.func()
      -- self._inIntervalFunc = false

      interval.timer = interval.duration
    end
  end

  for i = #self._delayedTasks, 1, -1 do
    local task = self._delayedTasks[i]
    task.ticks = task.ticks - 1
    if task.ticks <= 0 then
      task.func()
      table.remove(self._delayedTasks, i)
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

---Adds a delayed task. These tasks are called on the next call to the `update` method or after `ticks` calls to
---`update`.
---@param task fun() | {ticks: number, func: fun()}
function vTime.addDelayedTask(task)
  ticker:addDelayedTask(task)
end

---Processes the current intervals for one tick
---@param dt number
function vTime.update(dt)
  ticker:update(dt)
end