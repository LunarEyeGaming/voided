require "/scripts/util.lua"

local endAngle
local timer
local interpTime

function init()
  endAngle = util.toRadians(config.getParameter("endAngle"))
  timer = 0
  interpTime = config.getParameter("interpTime") or config.getParameter("timeToLive")
end

function update(dt)
  timer = timer + dt

  mcontroller.setRotation(util.easeInOutSin(timer / interpTime, 0, endAngle))
end
