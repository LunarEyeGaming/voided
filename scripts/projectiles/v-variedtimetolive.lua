require "/scripts/util.lua"

local oldInit = init or function() end

function init()
  oldInit()

  local range = config.getParameter("timeToLiveRange")
  if not range then
    error("Parameter 'timeToLiveRange' not given")
  end
  projectile.setTimeToLive(util.randomInRange(range))
end