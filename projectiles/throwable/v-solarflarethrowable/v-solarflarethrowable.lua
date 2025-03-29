local flashbangAction
local flashbangAirTime

local currentAirTime
local firstImpact

function init()
  flashbangAction = config.getParameter("flashbangAction")
  flashbangAirTime = config.getParameter("flashbangAirTime")

  currentAirTime = 0
  firstImpact = false
end

function update(dt)
  currentAirTime = currentAirTime + dt
end

function bounce()
  if currentAirTime >= flashbangAirTime and not firstImpact then
    projectile.processAction(flashbangAction)
  end

  firstImpact = true
end