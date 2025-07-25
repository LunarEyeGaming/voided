require "/scripts/vec2.lua"

local radius

local rotationalVelocity
local rotation

local oldInit = init or function() end
local oldUpdate = update or function() end

function init()
  oldInit()

  radius = config.getParameter("radius", 1)

  rotationalVelocity = 0
  rotation = 0
end

function update(dt)
  oldUpdate(dt)

  local velocity = mcontroller.velocity()

  local rotationalVelocityDir
  if velocity[1] < 0 then
    rotationalVelocityDir = -1
  else
    rotationalVelocityDir = 1
  end

  rotationalVelocity = vec2.mag(velocity) * rotationalVelocityDir / radius
  rotation = rotation - rotationalVelocity * dt
  mcontroller.setRotation(rotation)
end