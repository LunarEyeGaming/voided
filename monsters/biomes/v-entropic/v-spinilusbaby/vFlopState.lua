require "/scripts/util.lua"

vFlopState = {}

function vFlopState.enter()
  if mcontroller.liquidMovement() then return nil end

  return { }
end

function vFlopState.enterWith(parameters)
  if mcontroller.liquidMovement() or not parameters.flop then return nil end

  return { jumpTimer = 0, jumpDirection = 1 }
end

function vFlopState.enteringState(stateData)
  -- sb.logInfo("Entering flop state")

  animator.setAnimationState("movement", "flopping")
end

function vFlopState.update(dt, stateData)
  if mcontroller.liquidMovement() then return true end

  mcontroller.controlParameters({ bounceFactor = 0.9 })

  return false
end

function vFlopState.leavingState(stateData)

end
