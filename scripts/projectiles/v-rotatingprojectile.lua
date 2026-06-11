local rotVelocity
local rotationAmount

local oldInit = init or function() end
local oldUpdate = update or function() end

function init()
  oldInit()

  rotVelocity = config.getParameter("rotateRate") * 2 * math.pi
  rotationAmount = 0
end

function update(dt)
  oldUpdate(dt)

  rotationAmount = rotationAmount + rotVelocity * dt

  mcontroller.setRotation(rotationAmount)
end
