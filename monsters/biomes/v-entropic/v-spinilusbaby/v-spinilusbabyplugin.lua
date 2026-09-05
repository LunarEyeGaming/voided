require "/scripts/util.lua"

function turnAndBoost(direction, boostDelay, boostDuration, boostSpeed, waitTime)
  return function()
    mcontroller.controlFace(direction[1])
    setBodyDirection(direction)

    animator.setAnimationState("movement", "boostwindup")

    util.wait(boostDelay)

    animator.playSound("boost")

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