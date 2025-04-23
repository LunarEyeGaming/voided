local intervals = {}

vTime = {}

---Adds a function `func` to be periodically called every `duration` seconds.
---@param duration number
---@param func fun()
function vTime.addInterval(duration, func)
  table.insert(intervals, {duration = duration, func = func, timer = duration})
end

---Processes the current intervals for one tick
---@param dt number
function vTime.update(dt)
  for _, interval in ipairs(intervals) do
    interval.timer = interval.timer - dt

    if interval.timer <= 0 then
      interval.func()

      interval.timer = interval.duration
    end
  end
end