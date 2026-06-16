require "/scripts/util.lua"
require "/scripts/vec2.lua"
require "/scripts/interp.lua"

local freshCounter = 0

VRailgunFire = WeaponAbility:new()

function VRailgunFire:init()
  self.weapon:setStance(self.stances.idle)

  self.cooldownTimer = 0
  self.chargeTimer = 0

  self.weapon.onLeaveAbility = function()
    self.weapon:setStance(self.stances.idle)
    self:reset()
  end

  self.beamEndProjectileConfig = self.beamEndProjectileConfig or {}
  self.beamEndProjectileConfig.power = self:leveledBaseDamage() * self.beamEndDamageFactor
  self.beamEndProjectileConfig.powerMultiplier = activeItem.ownerPowerMultiplier()

  freshCounter = 0  -- Force it to start at 0 every time.
end

function VRailgunFire:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)

  self.cooldownTimer = math.max(0, self.cooldownTimer - self.dt)

  if self.fireMode == (self.activatingFireMode or self.abilitySlot)
    and self.cooldownTimer == 0
    and not self.weapon.currentAbility
    and not world.lineTileCollision(mcontroller.position(), self:firePosition())
    and not status.resourceLocked("energy") then

    self:setState(self.charge)
  end
end

function VRailgunFire:charge()
  self.weapon:setStance(self.stances.charge)

  animator.setAnimationState("firing", "charge")
  collidePoint = nil

  self.chargeTimer = self.chargeTime

  while self.fireMode == (self.activatingFireMode or self.abilitySlot) do
    self.chargeTimer = math.max(self.chargeTimer - self.dt, 0)

    if self.chargeTimer == 0 then
      self:setState(self.charged)
    end

    coroutine.yield()
  end
  animator.setAnimationState("firing", "idle")
end

function VRailgunFire:charged()
  while self.fireMode == (self.activatingFireMode or self.abilitySlot) do
    coroutine.yield()
  end

  self:setState(self.fire)
end

function VRailgunFire:fire()
  if world.lineTileCollision(mcontroller.position(), self:firePosition()) then
    animator.setAnimationState("firing", "idle")
    self.cooldownTimer = self.cooldownTime or 0
    -- self:setState(self.cooldown, self.cooldownTimer)
    return
  end

  if not status.overConsumeResource("energy", self.energyCost) then
    return
  end

  self:kickback()

  local projectilePos = self:drawBeam()
  self:spawnProjectile(projectilePos)

  self.weapon:setStance(self.stances.fire)

  animator.setAnimationState("firing", "fire")
  animator.playSound("fire")
  self:spawnMuzzleFlash()

  if self.stances.fire.duration then
    util.wait(self.stances.fire.duration)
  end

  self.cooldownTimer = self.cooldownTime or 0

  self:setState(self.cooldown, self.cooldownTimer)
end

function VRailgunFire:cooldown(duration)
  self.weapon:setStance(self.stances.cooldown)
  self.weapon:updateAim()

  local progress = 0

  util.wait(self.beamDamageTime, function()
    self:setDamage()

    self:animateStance(progress, self.stances.cooldown, self.stances.idle)

    progress = math.min(1.0, progress + (self.dt / duration))
  end)

  util.wait(duration - self.beamDamageTime, function()
    self:animateStance(progress, self.stances.cooldown, self.stances.idle)

    progress = math.min(1.0, progress + (self.dt / duration))
  end)
end

function VRailgunFire:animateStance(progress, fromStance, toStance)
  local from = fromStance.weaponOffset or {0,0}
  local to = toStance.weaponOffset or {0,0}
  self.weapon.weaponOffset = {interp.linear(progress, from[1], to[1]), interp.linear(progress, from[2], to[2])}

  self.weapon.relativeWeaponRotation = util.toRadians(interp.linear(progress, fromStance.weaponRotation, toStance.weaponRotation))
  self.weapon.relativeArmRotation = util.toRadians(interp.linear(progress, fromStance.armRotation, toStance.armRotation))
end

function VRailgunFire:firePosition()
  return vec2.add(mcontroller.position(), activeItem.handPosition(self.weapon.muzzleOffset))
end

function VRailgunFire:aimVector(angleAdjust, inaccuracy)
  local aimVector = vec2.rotate({1, 0}, self.weapon.aimAngle + angleAdjust + sb.nrand(inaccuracy, 0))
  aimVector[1] = aimVector[1] * mcontroller.facingDirection()
  return aimVector
end

function VRailgunFire:drawBeam()
  local beamEnd = vec2.add(self:firePosition(), vec2.mul(self:aimVector(0, 0), self.beamLength))

  local collidePoint = world.lineCollision(self:firePosition(), beamEnd)
  if collidePoint then
    beamEnd = collidePoint
  end

  -- local beamLength = world.magnitude(self:firePosition(), beamEnd)
  -- local laserBeamOffsetX = beamLength / 2
  -- local laserBeamOffset = {laserBeamOffsetX, 0}
  -- animator.translateTransformationGroup("laserbeam", laserBeamOffset)
  -- animator.setGlobalTag("beamDirectives", "scalenearest;"..beamLength..";1")
  -- animator.setAnimationState("beamfire", "fire")

  self:emitParticles(self:firePosition(), beamEnd, 1)

  return beamEnd
end

function VRailgunFire:emitParticles(startPoint, endPoint, stepSize)
  local angle = vec2.angle(world.distance(endPoint, startPoint))

  local particleCycleLength = 4
  local particleSpeed = -2

  local particles = {}  -- Particles to emit

  -- Spawn particles
  local nextDistance = 0
  local particleNumber = 0
  while nextDistance < world.magnitude(startPoint, endPoint) do

    local particleSpecs = copy(self.beamParticleSpecs)
    particleSpecs.animation = util.replaceTag(particleSpecs.animation, "number", particleNumber + 1)
    particleSpecs.rotation = util.toDegrees(angle)
    particleSpecs.initialVelocity = vec2.withAngle(angle, particleSpeed)
    particleSpecs.position = vec2.add(startPoint, vec2.withAngle(angle, nextDistance))

    table.insert(particles, particleSpecs)
    nextDistance = nextDistance + stepSize
    particleNumber = (particleNumber + 1) % particleCycleLength
  end

  -- Send particles to the script
  activeItem.setScriptedAnimationParameter("particles", particles)
  activeItem.setScriptedAnimationParameter("emissionId", self:fresh())
end

function VRailgunFire:spawnProjectile(projectilePos)
  if not world.lineTileCollision(mcontroller.position(), self:firePosition()) then
    world.spawnProjectile(self.beamEndProjectileType, projectilePos, activeItem.ownerEntityId(), self:aimVector(0, 0),
        false, self.beamEndProjectileConfig)
  end
end

function VRailgunFire:spawnMuzzleFlash()
  world.spawnProjectile(self.muzzleFlashProjectileType, self:firePosition(), activeItem.ownerEntityId(),
      self:aimVector(0, 0))
end

function VRailgunFire:setDamage()
  local damageArea = {
    vec2.add({0, self.beamThickness}, self.weapon.muzzleOffset),
    vec2.add({0, -self.beamThickness}, self.weapon.muzzleOffset),
    vec2.add({self.beamLength, -self.beamThickness}, self.weapon.muzzleOffset),
    vec2.add({self.beamLength, -self.beamThickness}, self.weapon.muzzleOffset)
  }
  local baseDamage = self.baseDamage
  self.weapon:setDamage({baseDamage = baseDamage, damageSourceKind = self.beamDamageKind, knockback = 0,
      damageRepeatTimeout = 1.0}, damageArea)
end

function VRailgunFire:kickback()
  mcontroller.controlApproachVelocity(vec2.mul(self:aimVector(0, 0), -self.kickbackSpeed), self.kickbackControlForce)
end

function VRailgunFire:fresh()
  local temp = freshCounter
  freshCounter = freshCounter + 1
  return temp
end

function VRailgunFire:leveledBaseDamage()
  return (self.baseDamage * root.evalFunction("weaponDamageLevelMultiplier", config.getParameter("level", 1)))
end

function VRailgunFire:reset()
  activeItem.setScriptedAnimationParameter("particles", {})
  activeItem.setScriptedAnimationParameter("emissionId", -1)  -- Guarantees that the first call of fresh() is unique.
end

function VRailgunFire:uninit()
  self:reset()
end