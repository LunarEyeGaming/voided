require "/scripts/v-vec2.lua"

vMeleeAttackState = {}

function vMeleeAttackState.enter()
  if not self.target or not targetValid(self.target) then
    return nil
  end

  monster.setAggressive(true)

  return { timer = config.getParameter("attackWindupTime"), stage = "windup" }
end

function vMeleeAttackState.enteringState(stateData)
  -- sb.logInfo("Entering attack state")
end

function vMeleeAttackState.update(dt, stateData)
  if not self.target then return true end

  stateData.timer = stateData.timer - dt

  local toTarget = entity.distanceToEntity(self.target)

  if stateData.stage == "windup" then
    animator.setAnimationState("movement", "swimSlow")
    animator.setAnimationState("attack", "meleewindup")
    setBodyDirection(toTarget)
    if stateData.timer <= 0 then
      stateData.stage = "charge"
      animator.setAnimationState("attack", "melee")
      animator.playSound("charge", -1)
      stateData.chargeDirection = toTarget
      stateData.timer = config.getParameter("attackChargeTime")
    end
  elseif stateData.stage == "charge" then
    if collides("blockedSensors") then
      animator.playSound("crash")
      return true, config.getParameter("attackCooldownTime")
    end

    stateData.chargeDirection = vVec2.rotateTowardTarget(stateData.chargeDirection, toTarget, util.toRadians(config.getParameter("attackTurnRate")), dt)

    monster.setDamageOnTouch(true)
    mcontroller.controlParameters({flySpeed = config.getParameter("attackChargeSpeed")})
    move(stateData.chargeDirection, true, true)

    if stateData.timer <= 0 then
      stateData.stage = "chargeWinddown"
      stateData.timer = config.getParameter("attackWinddownTime")
      animator.setAnimationState("attack", "idle")
    end
  elseif stateData.stage == "chargeWinddown" then
    if collides("blockedSensors") then
      animator.playSound("crash")
      return true, config.getParameter("attackCooldownTime")
    end

    monster.setDamageOnTouch(false)
    move(stateData.chargeDirection, false)
  end

  return stateData.timer <= 0, config.getParameter("attackCooldownTime")
end

function vMeleeAttackState.leavingState(stateData)
  monster.setDamageOnTouch(false)
  monster.setAggressive(false)
  animator.setAnimationState("attack", "idle")
  animator.stopAllSounds("charge")
end