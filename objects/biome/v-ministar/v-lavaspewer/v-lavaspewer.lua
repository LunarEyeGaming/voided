require "/scripts/util.lua"

local activeDuration
local inactiveDuration
local liquidId
local liquidRate

local spewPos
local timer
local isActive

function init()
  activeDuration = config.getParameter("activeDuration", 5)
  inactiveDuration = config.getParameter("inactiveDuration", 5)
  liquidId = config.getParameter("liquidId", 1)
  liquidRate = config.getParameter("liquidRate", 1)

  spewPos = object.position()
  timer = 0
  isActive = util.randomFromList({true, false})
end

function update(dt)
  if isActive then
    spawnLiquid()
  else
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

function spawnLiquid()
  world.spawnLiquid(object.position(), liquidId, liquidRate)
end

function drainLiquid()
  if world.liquidAt(spewPos) then
    world.destroyLiquid(spewPos)
  end
end