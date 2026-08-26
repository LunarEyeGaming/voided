require "/scripts/util.lua"

local activeTime
local inactiveTime

local oldInit = init or function() end
local oldUpdate = update or function() end

local isActive
local timer

function init()
  oldInit()

  activeTime = 15
  inactiveTime = 60

  isActive = true
  timer = 0
end

function update(dt)
  oldUpdate(dt)

  timer = timer - dt

  if timer <= 0 and isActive then
    timer = util.randomInRange(inactiveTime)
    isActive = false
    animator.setAnimationState("coralState", "inactive")
    v_statusEffectObject_setActive(false)
  end

  if timer <= 0 and not isActive then
    timer = util.randomInRange(activeTime)
    isActive = true
    animator.setAnimationState("coralState", "active")
    v_statusEffectObject_setActive(true)
  end
end