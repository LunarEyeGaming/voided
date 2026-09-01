require "/scripts/v-attack.lua"

vRangedAttackState = {}

function vRangedAttackState.enter()
  if not self.target or not targetValid(self.target) then
    return nil
  end

  return { timer = config.getParameter("rangedApproachTime"), stage = "approach" }
end

function vRangedAttackState.enteringState(stateData)
  -- sb.logInfo("Entering attack state")
end

function vRangedAttackState.update(dt, stateData)
  if not self.target then return true end

  stateData.timer = stateData.timer - dt

  local toTarget = entity.distanceToEntity(self.target)

  local minDistance = config.getParameter("rangedMinDistance")
  local maxDistance = config.getParameter("rangedMaxDistance")

  local distance = vec2.mag(toTarget)

  if stateData.stage == "approach" then
    if distance < minDistance then
      local toTarget = vec2.mul(toTarget, -1)
      move(toTarget, true)
    elseif distance > maxDistance then
      move(toTarget, true)
    else
      animator.setAnimationState("movement", "swimSlow")
      animator.setAnimationState("attack", "shootwindup")
      stateData.stage = "windup"
      stateData.timer = config.getParameter("rangedWindupTime")
    end
  elseif stateData.stage == "windup" then
    world.debugLine(mcontroller.position(), vec2.add(mcontroller.position(), toTarget), "green")
    mcontroller.controlFace(toTarget[1])
    setBodyDirection(toTarget)
    if stateData.timer <= 0 then
      stateData.stage = "shoot"
      animator.setAnimationState("attack", "shooting")
      stateData.shootDirection = toTarget
      stateData.timer = config.getParameter("rangedAttackDelay")
    end
  elseif stateData.stage == "shoot" then
    if stateData.timer <= 0 then
      local baseOffset = config.getParameter("rangedProjectileOffset")
      local rotatedOffset = vec2.rotate(baseOffset, vec2.angle(stateData.shootDirection))
      local projectilePos = vec2.add(mcontroller.position(), rotatedOffset)

      local params = config.getParameter("rangedProjectileParameters", {})

      if config.getParameter("rangedScalePower") then
        params.power = vAttack.scaledPower(params.power or 10)
      end

      world.spawnProjectile(
        config.getParameter("rangedProjectileType"),
        projectilePos,
        entity.id(),
        stateData.shootDirection,
        false,
        params
      )

      local soundName = config.getParameter("rangedShootSound")
      if soundName and animator.hasSound(soundName) then
        animator.playSound(soundName)
      end

      stateData.stage = "winddown"
      stateData.timer = config.getParameter("rangedWinddownTime")
    end
  end

  return stateData.timer <= 0, config.getParameter("rangedCooldown")
end

function vRangedAttackState.leavingState(stateData)
  animator.setAnimationState("attack", "idle")
end
