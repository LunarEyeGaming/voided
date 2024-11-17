--[[
  A simple script that outputs a signal for a specific amount of time whenever it receives an electrical current.
]]

local signalTime

local timer

function init()
  signalTime = config.getParameter("signalTime", 1.0)

  timer = nil
end

function update(dt)
  -- If a signal is currently active...
  if timer then
    -- Decrement timer
    timer = timer - dt
    -- If the signal timer has run out...
    if timer <= 0 then
      -- Deactivate signal.
      object.setAllOutputNodes(false)
      timer = nil
    end
  end
end

function v_onShockwaveReceived()
  -- Activate signal
  object.setAllOutputNodes(true)
  timer = signalTime
  return true
end