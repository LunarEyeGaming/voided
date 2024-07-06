--[[
  A plugin to the sliding door script (in `/objects/wired/v-slidingdoor/slidingdoor.lua`). Translates a second
  transformation group to go in the opposite direction from the first transformation group. Also animates the door to
  unlock and lock prior to opening and after closing respectively.
]]

local oldUpdateDoor = updateDoor or function() end
local oldInit = init or function() end

local setUnlockState
local setLockState

function init()
  oldInit()
end

function updateDoor(progress, endOffset)
  oldUpdateDoor(progress, endOffset)

  -- If the door is active and the unlock state has not been set...
  if storage.active and not setUnlockState then
    setUnlockState = true
    setLockState = false
    animator.setAnimationState("doorState", "unlocking")
  -- Otherwise, if the door is not active, the door has finished transitioning and the lock state has not been set...
  elseif not storage.active and progress == 0.0 and not setLockState then
    setLockState = true
    setUnlockState = false
    animator.setAnimationState("doorState", "locking")
  end

  -- Move top segment of the door
  animator.resetTransformationGroup("doortop")
  animator.translateTransformationGroup("doortop", {
    util.lerp(progress, 0, endOffset[1]),
    util.lerp(progress, 0, -endOffset[2])
  })
end