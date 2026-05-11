require "/scripts/util.lua"

-- Wander state: Rotate to a random direction that won't make it run into a wall, then give a short boost.
-- Pursue state:
-- how tf do you do custom pathfinding???
--

function turnAndBoost(direction, boostDelay, boostDuration, boostSpeed)
  return function()
    setBodyDirection(direction)

    util.wait(boostDelay)

    util.wait(boostDuration, function()
        if boostSpeed then
          mcontroller.controlParameters({flySpeed = boostSpeed})
        end
        move(direction, true, true)
    end)
  end
end