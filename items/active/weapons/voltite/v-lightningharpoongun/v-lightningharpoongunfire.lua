require "/scripts/util.lua"
require "/scripts/interp.lua"
require "/scripts/v-animator.lua"

-- Base gun fire ability
HarpoonGunFire = WeaponAbility:new()

function HarpoonGunFire:init()
  self.damageConfig.baseDamage = self.baseDps * self.fireTime * self.chainDamageFactor
  self.weapon:setStance(self.stances.idle)

  self.cooldownTimer = 0

  self.weapon.onLeaveAbility = function()
    self.weapon:setStance(self.stances.idle)
  end
  
  self.projectileId = nil
  self.anchored = false
  
  self.frameTimer = 0
end

function HarpoonGunFire:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)

  self.cooldownTimer = math.max(0, self.cooldownTimer - self.dt)

  if self.fireMode == (self.activatingFireMode or self.abilitySlot) then
    if not self.projectileId or not world.entityExists(self.projectileId) then
      if not self.weapon.currentAbility
        and self.cooldownTimer == 0
        and not status.resourceLocked("energy")
        and not world.lineTileCollision(mcontroller.position(), self:firePosition())
        and status.overConsumeResource("energy", self:energyPerShot()) then

        self:setState(self.fire)
      end
    elseif self.prevFireMode ~= (self.activatingFireMode or self.abilitySlot) then
      self:cancel()
    end
  end
  
  self.prevFireMode = self.fireMode
  
  self:trackProjectile()
end

function HarpoonGunFire:fire()
  self.weapon:setStance(self.stances.fire)

  self.projectileId = self:fireProjectile()
  self:muzzleFlash()
  animator.playSound("chainLoop", -1)

  if self.stances.fire.duration then
    util.wait(self.stances.fire.duration)
  end

  self:setState(self.postFire)
end

function HarpoonGunFire:postFire()
  self.weapon:setStance(self.stances.cooldown)
  self.weapon:updateAim()

  local progress = 0
  util.wait(self.stances.cooldown.duration, function()
    local from = self.stances.cooldown.weaponOffset or {0,0}
    local to = self.stances.idle.weaponOffset or {0,0}
    self.weapon.weaponOffset = {interp.linear(progress, from[1], to[1]), interp.linear(progress, from[2], to[2])}

    self.weapon.relativeWeaponRotation = util.toRadians(interp.linear(progress, self.stances.cooldown.weaponRotation, self.stances.idle.weaponRotation))
    self.weapon.relativeArmRotation = util.toRadians(interp.linear(progress, self.stances.cooldown.armRotation, self.stances.idle.armRotation))

    progress = math.min(1.0, progress + (self.dt / self.stances.cooldown.duration))
  end)
  
  self:setState(self.preAnchor)
end

function HarpoonGunFire:preAnchor()
  while self.projectileId and world.entityExists(self.projectileId) do
    if not self.anchored then
      self.anchored = world.callScriptedEntity(self.projectileId, "anchored")
    else
      self:setState(self.active)
    end
    coroutine.yield()
  end

  self.cooldownTimer = self.fireTime
end

function HarpoonGunFire:active()
  animator.stopAllSounds("chainLoop")
  
  animator.playSound("anchoredChainLoop", -1)

  while self.projectileId and world.entityExists(self.projectileId) do
    local chainLength = world.magnitude(self:firePosition(), world.entityPosition(self.projectileId))
    self.weapon:setDamage(self.damageConfig, {self.weapon.muzzleOffset, {self.weapon.muzzleOffset[1] + chainLength, self.weapon.muzzleOffset[2]}}, self.fireTime)
    if not status.overConsumeResource("energy", self.activeEnergyUsage * self.dt) then
      break
    end
    coroutine.yield()
  end
  
  animator.stopAllSounds("anchoredChainLoop")

  self.cooldownTimer = self.fireTime
end

function HarpoonGunFire:muzzleFlash()
  animator.setAnimationState("firing", "fire")
  animator.burstParticleEmitter("muzzleFlash")
  animator.playSound("fire")
end

function HarpoonGunFire:fireProjectile(projectileType, projectileParams, inaccuracy, firePosition)
  local params = sb.jsonMerge(self.projectileParameters, projectileParams or {})
  params.power = self:damagePerShot()
  params.powerMultiplier = activeItem.ownerPowerMultiplier()
  params.speed = util.randomInRange(params.speed)

  if not projectileType then
    projectileType = self.projectileType
  end
  if type(projectileType) == "table" then
    projectileType = projectileType[math.random(#projectileType)]
  end

  local projectileId = 0
  if params.timeToLive then
    params.timeToLive = util.randomInRange(params.timeToLive)
  end

  projectileId = world.spawnProjectile(
      projectileType,
      firePosition or self:firePosition(),
      activeItem.ownerEntityId(),
      self:aimVector(inaccuracy or self.inaccuracy),
      false,
      params
    )
  return projectileId
end

function HarpoonGunFire:firePosition()
  return vec2.add(mcontroller.position(), activeItem.handPosition(self.weapon.muzzleOffset))
end

function HarpoonGunFire:aimVector(inaccuracy)
  local aimVector = vec2.rotate({1, 0}, self.weapon.aimAngle + sb.nrand(inaccuracy, 0))
  aimVector[1] = aimVector[1] * mcontroller.facingDirection()
  return aimVector
end

function HarpoonGunFire:energyPerShot()
  return self.energyUsage * self.fireTime * (self.energyUsageMultiplier or 1.0)
end

function HarpoonGunFire:damagePerShot()
  return (self.baseDamage or (self.baseDps * self.fireTime)) * (self.baseDamageMultiplier or 1.0) * config.getParameter("damageLevelMultiplier")
end

function HarpoonGunFire:cancel()
  if self.projectileId and world.entityExists(self.projectileId) then
    world.callScriptedEntity(self.projectileId, "kill")
  end
  self.projectileId = nil
  
  self:reset()
end

function HarpoonGunFire:trackProjectile()
  if not self.projectileId or not world.entityExists(self.projectileId) then
    return
  end
  
  local projectilePosition = world.entityPosition(self.projectileId)
  
  local aimVector = world.distance(projectilePosition, mcontroller.position())
  
  if vec2.mag(aimVector) > self.maxChainLength then
    self:cancel()
    return
  end

  self.weapon.aimDirection = util.toDirection(aimVector[1])
  aimVector[1] = aimVector[1] * self.weapon.aimDirection
  self.weapon.aimAngle = vec2.angle(aimVector)
  
  self:renderChain(projectilePosition)
end

function HarpoonGunFire:renderChain(endPos)
  local newChain
  if self.anchored then
    newChain = copy(self.chainAnchored)
    
    local frame = vAnimator.frameNumber(self.frameTimer, self.anchoredChainFrameCycle, 1, self.anchoredChainNumFrames)

    newChain.startSegmentImage = util.replaceTag(newChain.startSegmentImage, "frame", frame)
    newChain.segmentImage = util.replaceTag(newChain.segmentImage, "frame", frame)
    newChain.endSegmentImage = util.replaceTag(newChain.endSegmentImage, "frame", frame)
    
    self.frameTimer = (self.frameTimer + script.updateDt()) % self.anchoredChainFrameCycle
  else
    newChain = copy(self.chain)
  end

  newChain.startPosition = endPos
  newChain.endOffset = self.weapon.muzzleOffset

  activeItem.setScriptedAnimationParameter("chains", {newChain})
end

function HarpoonGunFire:uninit()
  self:cancel()
end

function HarpoonGunFire:reset()
  animator.stopAllSounds("chainLoop")
  animator.stopAllSounds("anchoredChainLoop")

  activeItem.setScriptedAnimationParameter("chains", {})
  animator.setAnimationState("firing", "idle")
  self.anchored = false
end
