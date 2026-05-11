require "/scripts/util.lua"

-- Wander state: Rotate to a random direction that won't make it run into a wall, then give a short boost.
-- Pursue state:
-- how tf do you do custom pathfinding???
--

function turnAndBoost(direction, boostDelay, boostDuration, boostSpeed, waitTime)
  return function()
    mcontroller.controlFace(direction[1])
    setBodyDirection(direction)

    animator.setAnimationState("movement", "boostwindup")

    util.wait(boostDelay)

    util.wait(boostDuration, function()
        if boostSpeed then
          mcontroller.controlParameters({flySpeed = boostSpeed})
        end
        move(direction, true, true)
    end)

    animator.setAnimationState("movement", "idle")

    util.wait(waitTime or 0)
  end
end