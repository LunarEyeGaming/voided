vMeleeAttackState = {}

function vMeleeAttackState.enter()
  if not self.target or not targetValid(self.target) then
    return nil
  end

  monster.setAggressive(true)

  return { timer = config.getParameter("attackApproachTime"), stage = "approach" }
end

function vMeleeAttackState.enteringState(stateData)
  -- sb.logInfo("Entering attack state")
end

function vMeleeAttackState.update(dt, stateData)
  if not self.target then return true end

  stateData.timer = stateData.timer - dt

  local toTarget = entity.distanceToEntity(self.target)

  if stateData.stage == "approach" then
    move(toTarget, true)
    if vec2.mag(toTarget) <= config.getParameter("attackStartDistance") then
      -- sb.logInfo("winding up...")
      animator.setAnimationState("movement", "swimSlow")
      animator.setAnimationState("attack", "meleewindup")
      stateData.stage = "windup"
      stateData.timer = config.getParameter("attackWindupTime")
    end
  elseif stateData.stage == "windup" then
    setBodyDirection(toTarget)
    if stateData.timer <= 0 then
      -- sb.logInfo("charging...")
      stateData.stage = "charge"
      animator.setAnimationState("attack", "melee")
      animator.playSound("charge")
      stateData.chargeDirection = toTarget
      stateData.timer = config.getParameter("attackChargeTime")
    end
  elseif stateData.stage == "charge" then
    if collides("blockedSensors") then return true end

    if animator.animationState("attack") == "melee" then
      monster.setDamageOnTouch(true)
      mcontroller.controlParameters({flySpeed = config.getParameter("attackChargeSpeed")})
      move(stateData.chargeDirection, true, true)
    else
      monster.setDamageOnTouch(false)
      move(stateData.chargeDirection, false)
    end
  end

  return stateData.timer <= 0
end

function vMeleeAttackState.leavingState(stateData)
  monster.setDamageOnTouch(false)
  monster.setAggressive(false)
end
