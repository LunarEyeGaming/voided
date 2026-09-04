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

  local maxXDistance = config.getParameter("attackMaxXDistance")
  local minXDistance = config.getParameter("attackMinXDistance")
  local maxYDistance = config.getParameter("attackMaxYDistance")
  local minYDistance = config.getParameter("attackMinYDistance")

  if stateData.stage == "approach" then
    local absXDistance = math.abs(toTarget[1])
    local absYDistance = math.abs(toTarget[2])

    local moveDir = {0, 0}
    local inXRange = false
    local inYRange = false

    -- Calculate x movement (and check if in range)
    if absXDistance > maxXDistance then
      moveDir[1] = toTarget[1]
    elseif absXDistance < minXDistance then
      moveDir[1] = -toTarget[1]
    else
      inXRange = true
    end

    -- Calculate y movement (and check if in range)
    if absYDistance > maxYDistance then
      moveDir[2] = toTarget[2]
    elseif absYDistance < minYDistance then
      moveDir[2] = -toTarget[2]
    else
      inYRange = true
    end

    if inXRange and inYRange then
      stateData.stage = "windup"
      stateData.timer = config.getParameter("attackWindupTime")
    else
      move(moveDir, nil, true)
    end
  elseif stateData.stage == "windup" then
    animator.setAnimationState("movement", "swimSlow")
    animator.setAnimationState("attack", "meleewindup")
    setBodyDirection(toTarget)
    if stateData.timer <= 0 then
      -- sb.logInfo("charging...")
      stateData.stage = "charge"
      animator.setAnimationState("attack", "melee")
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
