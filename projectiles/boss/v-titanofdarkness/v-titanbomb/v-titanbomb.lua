local target
local followTime

local followTimer

function init()
  target = config.getParameter("target")
  followTime = config.getParameter("followTime")

  followTimer = followTime
end

function update(dt)
  if not world.entityExists(target) then return end

  if followTimer > 0 then
    mcontroller.setPosition(world.entityPosition(target))

    followTimer = followTimer - dt
  end
end