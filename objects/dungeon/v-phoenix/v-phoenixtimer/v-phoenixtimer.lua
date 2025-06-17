-- TODO: Simplify this code.

-- Constants
local PULSE_NODE = 0
local LOCK_NODE = 1

-- Parameters
local duration
local handPivot

-- State variables
local isLocked
local outOfTime  -- whether or not the timer has run out of time

-- storage.endTime is the time at which the timer runs out.
-- storage.timeRemaining is the time remaining. Used when the timer is locked.

-- Hooks
function init()
  duration = config.getParameter("duration")
  handPivot = animator.partPoint("hand", "rotationPivot")

  isLocked = storage.isLocked or false
  outOfTime = false

  if storage.endTime then
    local timeRemaining = storage.timeRemaining or storage.endTime - world.time()
    if timeRemaining > 0 then
      animator.setAnimationState("clock", "on")
    end
  end

  if storage.isLocked then
    animator.setAnimationState("lock", "locked")
  end
end

function update(dt)
  if storage.endTime then
    if not isLocked then
      local timeRemaining = math.max(0, storage.endTime - world.time())

      world.debugText("%s", timeRemaining, object.position(), "green")
      animator.resetTransformationGroup("hand")
      -- Direction is clockwise when facing right, counterclockwise otherwise.
      animator.rotateTransformationGroup("hand", 2 * math.pi * timeRemaining / duration, handPivot)

      if timeRemaining == 0 and not outOfTime then
        object.setAllOutputNodes(false)

        animator.setAnimationState("clock", "off")

        outOfTime = true
      end
    else
      local timeRemaining = storage.timeRemaining
      animator.resetTransformationGroup("hand")
      -- Direction is clockwise when facing right, counterclockwise otherwise.
      animator.rotateTransformationGroup("hand", 2 * math.pi * timeRemaining / duration, handPivot)
    end
  end
end

function onInputNodeChange(args)
  if args.node == PULSE_NODE then
    -- Set end time ONCE.
    if args.level and not storage.endTime then
      storage.endTime = world.time() + duration
      object.setAllOutputNodes(true)

      animator.setAnimationState("clock", "on")
    end
  elseif args.node == LOCK_NODE then
    isLocked = args.level

    if args.level then
      storage.timeRemaining = storage.endTime and storage.endTime - world.time() or duration  -- Record time remaining
    else
      -- If the timer has already activated...
      if storage.endTime then
        storage.endTime = world.time() + storage.timeRemaining  -- Apply time remaining.
      end
    end

    animator.setAnimationState("lock", isLocked and "locking" or "unlocking")
  end
end

function uninit()
  storage.isLocked = isLocked
end