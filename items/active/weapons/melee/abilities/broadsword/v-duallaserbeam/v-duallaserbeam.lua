require "/scripts/util.lua"
require "/items/active/weapons/weapon.lua"
require "/scripts/poly.lua"

local PIXELS_TO_BLOCK_RATIO = 8

DualBeam = WeaponAbility:new()

function DualBeam:init()
  self:reset()

  -- Guess used parts from partDamageConfigs and fill in parameters.
  self.laserPartSettings = {}
  for partName, damageConfig in pairs(self.partDamageConfigs) do
    self.laserPartSettings[partName] = animator.partProperty(partName, "movementSettings")

    damageConfig.baseDamage = self.baseDps * self.fireTime
    damageConfig.timeout = self.fireTime
    damageConfig.timeoutGroup = "alt" .. partName
  end

  -- Calculate power for each projectile, if not defined.
  for _, projectile in pairs(self.partProjectiles) do
    projectile.parameters = projectile.parameters or {}
    projectile.parameters.power = projectile.parameters.power or self.baseDps * self.fireTime *
        (projectile.damageMultiplier or 1.0) * self.weapon.damageLevelMultiplier * activeItem.ownerPowerMultiplier()
  end

  self.cooldownTimer = self.cooldownTime
  self.rotateTimer = 0
end

function DualBeam:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)

  self.cooldownTimer = math.max(0, self.cooldownTimer - self.dt)

  if self.weapon.currentAbility == nil
      and self.fireMode == "alt"
      and self.cooldownTimer == 0
      and not status.resourceLocked("energy") then

    self:setState(self.windup)
  end
end

function DualBeam:windup()
  self.weapon:setStance(self.stances.windup)
  self.weapon:updateAim()

  -- if self.boostSpeed then
  --   status.setPersistentEffects("weaponMovementAbility", {{stat = "activeMovementAbilities", amount = 1}})
  -- end

  animator.setAnimationState("laser", "windup")
  animator.playSound("laserCharge")

  local timer = 0
  util.wait(self.stances.windup.duration, function()
    -- Warm up the barrels (i.e., animate them).
    -- Multiplying self.dt with timer / self.stances.windup.duration makes the lasers speed up. Pretty hacky but it
    -- works.
    self.rotateTimer = self.rotateTimer + self.dt * timer / self.stances.windup.duration
    self:updateLasers()
    timer = timer + self.dt

    -- Interrupt if fire mode is not "alt" anymore.
    if self.fireMode ~= "alt" then
      animator.stopAllSounds("laserCharge")
      return true
    end
  end)

  -- Transition only if `fireMode` is "alt"
  if self.fireMode == "alt" then
    self:setState(self.fire)
  end
end

function DualBeam:fire()
  self.weapon:setStance(self.stances.fire)
  self.weapon:updateAim()

  animator.setAnimationState("laser", "fire")
  animator.playSound("laserStart")
  animator.playSound("laserLoop", -1)

  -- local params = copy(self.projectileParameters)
  -- params.power = self.baseDps * self.fireTime * config.getParameter("damageLevelMultiplier")
  -- params.powerMultiplier = activeItem.ownerPowerMultiplier()

  -- Spawn camera shaker and set focus entity to it.
  self.cameraShakerId = world.spawnProjectile("v-camerashaker", mcontroller.position(), entity.id())
  activeItem.setCameraFocusEntity(self.cameraShakerId)

  local explosionTimer = 0
  while self.fireMode == "alt" and status.overConsumeResource("energy", self.energyUsage * self.dt) do
    self.weapon:updateAim()

    -- Push away (copied from RocketSpear ability).
    if self.boostSpeed then
      local boostAngle = mcontroller.facingDirection() == 1 and self.weapon.aimAngle + math.pi or -self.weapon.aimAngle
      local vel = mcontroller.velocity()
      local speed = vec2.mag(vel)
      if speed <= self.boostSpeed then
        mcontroller.controlApproachVelocity(vec2.withAngle(boostAngle, self.boostSpeed), self.boostForce)
      else
        local angleDiff = math.abs(util.angleDiff(boostAngle, vec2.angle(vel)))
        local boostSpeedFactor = math.min(1, angleDiff / (math.pi * 0.5))
        local targetSpeed = boostSpeedFactor * self.boostSpeed + (1 - boostSpeedFactor) * speed
        mcontroller.controlApproachVelocity(vec2.withAngle(boostAngle, targetSpeed), self.boostForce)
      end
    end

    -- Animate laser beams and calculate damage sources.
    self.rotateTimer = self.rotateTimer + self.dt

    local partCollidePoints = self:updateLasers()

    -- Add damage sources.
    local damageSources = {}
    for partName, damageConfig in pairs(self.partDamageConfigs) do
      -- Add damage source.
      local damageArea = animator.transformPoly(damageConfig.poly, partName)
      table.insert(damageSources, self.weapon:damageSource(damageConfig, damageArea))
    end

    activeItem.setItemDamageSources(damageSources)

    -- Periodically make explosions at collision points, if provided.
    explosionTimer = explosionTimer - self.dt

    if explosionTimer <= 0 then
      for partName, projectile in pairs(self.partProjectiles) do
        -- If a collision point is provided...
        if partCollidePoints[partName] then
          -- Make explosion.
          world.spawnProjectile(projectile.type, partCollidePoints[partName], entity.id(),
              vec2.withAngle(self.weapon.aimAngle), false, projectile.parameters)
        end
      end

      explosionTimer = self.fireTime
    end

    -- fireTimer = math.max(0, fireTimer - self.dt)
    -- if fireTimer == 0 then
    --   fireTimer = self.fireTime
    --   local position = vec2.add(mcontroller.position(), activeItem.handPosition(animator.partPoint("chargeSwoosh", "projectileSource")))
    --   local aim = self.weapon.aimAngle + util.randomInRange({-self.inaccuracy, self.inaccuracy})
    --   if not world.lineTileCollision(mcontroller.position(), position) then
    --     world.spawnProjectile(self.projectileType, position, activeItem.ownerEntityId(), {mcontroller.facingDirection() * math.cos(aim), math.sin(aim)}, false, params)
    --   end
    -- end

    coroutine.yield()
  end

  animator.setAnimationState("laser", "winddown")
  animator.stopAllSounds("laserStart")
  animator.stopAllSounds("laserLoop")
  animator.playSound("laserStop")

  -- Make camera shaking entity stop.
  world.sendEntityMessage(self.cameraShakerId, "v-stopShake")

  -- Clear damage sources
  activeItem.setItemDamageSources()

  -- Wait self.cooldownTime to exit.
  local timer = self.cooldownTime
  util.wait(self.cooldownTime, function()
    -- Multiplying self.dt with timer / self.cooldownTime makes the lasers slow down. Pretty hacky but it works.
    self.rotateTimer = self.rotateTimer + self.dt * timer / self.cooldownTime
    self:updateLasers()
    timer = timer - self.dt
  end)

  self.cooldownTimer = self.cooldownTime
end

---Animates the lasers for one tick and returns a table mapping parts to collision points. This method depends on
---`self.rotateTimer`, which should be set before this method is called.
---@return table<string, Vec2F>
function DualBeam:updateLasers()
  local partCollidePoints = {}

  for partName, settings in pairs(self.laserPartSettings) do
    -- Calculate vertical offset
    local verticalOffset = settings.amplitude * math.sin(2 * math.pi * (self.rotateTimer / settings.period + settings.phase))
    animator.resetTransformationGroup(partName)
    animator.translateTransformationGroup(partName, {0, verticalOffset})

    local collideDistance
    -- Get collision point and distance.
    partCollidePoints[partName], collideDistance = self:getCollidePointAndDistance(partName)

    -- sb.logInfo("partName: %s, progress: %s", partName, (self.rotateTimer / settings.period + settings.phase) % 1)
    -- Between the first and third quarters of the period...
    if (self.rotateTimer / settings.period + settings.phase + 0.25) % 1 > 0.5 then
      -- Make the second beam visible and the first beam invisible.
      animator.setPartTag(partName, "beamVisibility", "")
      animator.setPartTag(partName.."barrel", "beamVisibility", "")
      animator.setPartTag(partName.."top", "beamVisibility", "?multiply=0000")
      animator.setPartTag(partName.."barreltop", "beamVisibility", "?multiply=0000")
    else
      -- Make the first beam visible and the second beam invisible.
      animator.setPartTag(partName, "beamVisibility", "?multiply=0000")
      animator.setPartTag(partName.."barrel", "beamVisibility", "?multiply=0000")
      animator.setPartTag(partName.."top", "beamVisibility", "")
      animator.setPartTag(partName.."barreltop", "beamVisibility", "")
    end

    -- If a collision distance is defined...
    if collideDistance then
      -- Crop the part accordingly.
      local beamHeight = animator.partProperty(partName, "imageHeight")
      local directives = string.format("?crop=0;0;%d;%d", math.floor(collideDistance * PIXELS_TO_BLOCK_RATIO), beamHeight)
      animator.setPartTag(partName, "beamDirectives", directives)
      animator.setPartTag(partName.."top", "beamDirectives", directives)
    else
      animator.setPartTag(partName, "beamDirectives", "")
      animator.setPartTag(partName.."top", "beamDirectives", "")
    end
  end

  return partCollidePoints
end

function DualBeam:getCollidePointAndDistance(partName)
  local collideStart = vec2.add(mcontroller.position(), activeItem.handPosition(animator.transformPoint({
      self.beamMuzzleOffset[1], self.beamMuzzleOffset[2]}, partName)))
  local collideEnd = vec2.add(mcontroller.position(), activeItem.handPosition(animator.transformPoint({
      self.beamLength + self.beamMuzzleOffset[1], self.beamMuzzleOffset[2]}, partName)))

  -- world.debugLine(collideStart, collideEnd, "green")

  local collidePoint = world.lineCollision(collideStart, collideEnd)

  return collidePoint, collidePoint and world.magnitude(collideStart, collidePoint) or nil
end

function DualBeam:reset()
  if self.boostSpeed then
    status.clearPersistentEffects("weaponMovementAbility")
  end
  animator.setAnimationState("laser", "inactive")

  for partName, _ in pairs(self.partDamageConfigs) do
    animator.setPartTag(partName, "beamDirectives", "")
  end

  -- Tell camera shaker to stop shaking if defined and existing.
  if self.cameraShakerId and world.entityExists(self.cameraShakerId) then
    world.sendEntityMessage(self.cameraShakerId, "v-stopShake")
  end

  animator.stopAllSounds("laserCharge")
  animator.stopAllSounds("laserStart")
  animator.stopAllSounds("laserLoop")
end

function DualBeam:uninit()
  self:reset()
end
