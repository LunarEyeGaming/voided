require "/scripts/util.lua"
require "/scripts/vec2.lua"

local oldInit = init or function() end

function init()
  oldInit()

  local range = config.getParameter("speedRange")
  local addYVelocity = config.getParameter("addYVelocity")

  local velocity = mcontroller.velocity()

  if range then
    local velocityDir = vec2.norm(velocity)
    velocity = vec2.mul(velocityDir, util.randomInRange(range))
  end

  if addYVelocity then
    velocity[2] = velocity[2] + addYVelocity
  end

  mcontroller.setVelocity(velocity)
end