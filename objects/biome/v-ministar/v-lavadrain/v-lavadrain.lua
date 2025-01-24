require "/scripts/util.lua"

local activeDuration
local inactiveDuration
local drainPos

local timer
local isActive

function init()
  activeDuration = config.getParameter("activeDuration", 5)
  inactiveDuration = config.getParameter("inactiveDuration", 5)
  drainPos = object.position()

  timer = 0
  isActive = util.randomFromList({true, false})
end

function update(dt)
  if isActive then
    drainLiquid()
  end

  if timer <= 0 then
    toggleState()
  end
  
  timer = timer - dt
end

function toggleState()
  if isActive then
    animator.setAnimationState("trapState", "off")
    timer = util.randomInRange(inactiveDuration)
  else
    animator.setAnimationState("trapState", "on")
    timer = util.randomInRange(activeDuration)
  end
  isActive = not isActive
end

function drainLiquid()
  if world.liquidAt(drainPos) then
    world.destroyLiquid(drainPos)
  end
end