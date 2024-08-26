local masterEntity
local rotationTime

local rotationTimer

function init()
  masterEntity = config.getParameter("masterEntity")
  rotationTime = config.getParameter("rotationTime")

  rotationTimer = 0
end

function update(dt)
  -- Follow masterEntity if it exists. Otherwise, die immediately.
  if world.entityExists(masterEntity) then
    mcontroller.setPosition(world.entityPosition(masterEntity))
  else
    projectile.die()
  end

  -- Update rotation
  rotationTimer = rotationTimer + dt
  mcontroller.setRotation(rotationTimer / rotationTime * 2 * math.pi)
end