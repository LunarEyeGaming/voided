local oldUpdateDoor = updateDoor or function() end

local setUnlockState
local setLockState

function updateDoor(progress)
  oldUpdateDoor(progress)

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
end