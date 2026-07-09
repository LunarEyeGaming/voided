require "/scripts/vec2.lua"

local timeToLive
local aimVector
local masterId
-- local damageParts

local offset

local timer

function init()
  masterId = config.getParameter("masterId")
  if not masterId or not world.entityExists(masterId) then
    timer = 0
    return
  end
  timeToLive = config.getParameter("timeToLive")
  aimVector = config.getParameter("aimVector", {0, 0})
  -- damageParts = config.getParameter("damageParts")

  offset = world.distance(mcontroller.position(), world.entityPosition(masterId))


  timer = timeToLive

  status.setStatusProperty("headId", masterId)

  animator.resetTransformationGroup("aim")
  animator.rotateTransformationGroup("aim", vec2.angle(aimVector))
  mcontroller.setRotation(vec2.angle(aimVector))
  mcontroller.controlFace(1)

  monster.setDamageOnTouch(true)
end

function update(dt)
  mcontroller.controlFace(1)

  timer = timer - dt
  if not masterId or not world.entityExists(masterId) then
    timer = 0
    return
  end

  -- monster.setDamageParts(damageParts)
  mcontroller.setPosition(vec2.add(world.entityPosition(masterId), offset))
end

function shouldDie()
  return timer <= 0
end