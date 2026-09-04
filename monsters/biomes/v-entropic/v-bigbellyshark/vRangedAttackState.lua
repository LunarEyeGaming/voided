require "/scripts/v-attack.lua"

vRangedAttackState = {}

function vRangedAttackState.enter()
  if not self.target or not targetValid(self.target) then
    return nil
  end

  monster.setAggressive(true)

  return { timer = config.getParameter("rangedApproachTime"), stage = "approach" }
end

function vRangedAttackState.enteringState(stateData)
  -- sb.logInfo("Entering attack state")
end

function vRangedAttackState.update(dt, stateData)
  if not self.target then return true end

  stateData.timer = stateData.timer - dt

  local toTarget = entity.distanceToEntity(self.target)

  local maxXDistance = config.getParameter("rangedMaxXDistance")
  local minXDistance = config.getParameter("rangedMinXDistance")
  local maxYDistance = config.getParameter("rangedMaxYDistance")
  local minYDistance = config.getParameter("rangedMinYDistance")

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
      stateData.timer = config.getParameter("rangedWindupTime")

      setBodyDirection({toTarget[1], 0})
      -- setBodyDirection({0, 1})
    else
      move(moveDir, nil, true)
    end
  elseif stateData.stage == "windup" then
    animator.setAnimationState("attack", "shootwindup")
    mcontroller.controlFace(toTarget[1])
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
      animator.setAnimationState("attack", "shootwinddown")
    end
  end

  return stateData.timer <= 0, config.getParameter("rangedCooldown")
end

function vRangedAttackState.leavingState(stateData)
  animator.setAnimationState("attack", "idle")
  monster.setAggressive(false)
end
