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

  table.insert(solarFlares, {
    duration = duration,
    potency = potency,
    spread = spread,
    x = mcontroller.position()[1],
    startTime = world.time()
  })

  world.setProperty("v-solarFlares", solarFlares)
end