local duration
local potency
local spread

function init()
  duration = config.getParameter("duration")
  potency = config.getParameter("potency")
  spread = config.getParameter("spread")
end

function destroy()
  local solarFlares = world.getProperty("v-solarFlares") or {}
  local time = world.time()

  -- Clean up expired entries
  for i = #solarFlares, 1, -1 do
    local flare = solarFlares[i]
    if time > flare.startTime + flare.duration then
      table.remove(solarFlares, i)
    end
  end

  table.insert(solarFlares, {
    duration = duration,
    potency = potency,
    spread = spread,
    x = mcontroller.position()[1],
    startTime = time
  })

  world.setProperty("v-solarFlares", solarFlares)
end