require "/scripts/util.lua"
require "/scripts/vec2.lua"

local oldInit = init or function() end

function init()
  oldInit()

  local range = config.getParameter("speedRange")
  if not range then
    error("Parameter 'speedRange' not given")
  end
  local velocityDir = vec2.norm(mcontroller.velocity())
  mcontroller.setVelocity(vec2.mul(velocityDir, util.randomInRange(range)))
end