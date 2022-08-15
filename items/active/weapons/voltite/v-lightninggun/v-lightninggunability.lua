require "/scripts/util.lua"
require "/scripts/interp.lua"
require "/scripts/vec2.lua"

TeslaStream = WeaponAbility:new()

function TeslaStream:init()
  self.weapon:setStance(self.stances.idle)
  self.chargeTimer = self.chargeTime or 0
  self.fireTimer = self.fireTime or 0
  self.damageConfig.baseDamage = self.baseDps * self.fireTime
  self.halfFov = util.toRadians(self.fov) / 2

  self.weapon.onLeaveAbility = function()
    self.weapon:setStance(self.stances.idle)
    activeItem.setScriptedAnimationParameter("lightning", {})
    animator.stopAllSounds("fireLoop")
  end
  self.arcCooldownTimer = self.fireTime
  self.groundLightningTimer = self.groundLightningInterval
  
  self.groundLightning = {}
end

function TeslaStream:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)

  if self.fireMode == (self.activatingFireMode or self.abilitySlot)
    and not self.weapon.currentAbility
    and not world.lineTileCollision(mcontroller.position(), self:firePosition())
    and not status.resourceLocked("energy") then
    
    self:setState(self.fire)
  end
  self.arcCooldownTimer = math.max(0, self.arcCooldownTimer - dt)
  self.groundLightningTimer = self.groundLightningTimer - self.dt
end

function TeslaStream:fire()
  self.weapon:setStance(self.stances.fire)

  animator.playSound("fireStart")
  animator.playSound("fireLoop", -1)

  while self.fireMode == (self.activatingFireMode or self.abilitySlot) and status.overConsumeResource("energy", (self.energyUsage or 0) * self.dt) do
    local beamStart = self:firePosition()
    
    local entities = world.entityQuery(beamStart, self.connectRadius, {includedTypes = {"monster", "npc"}})
    local targeted = {}
  
    local power = self:damagePerShot()

    entities = util.filter(entities, function(x)
      local entityPos = world.nearestTo(beamStart, world.entityPosition(x))
      local entCollidePoint = world.lineCollision(beamStart, entityPos)
      
      -- The angle, in radians, between the gun's aim vector and the target vector.
      local sightCloseness = math.abs(util.angleDiff(vec2.angle(self:aimVector(0)), vec2.angle(world.distance(entityPos, beamStart))))
      return world.entityCanDamage(entity.id(), x) and not entCollidePoint and sightCloseness <= self.halfFov
    end)

    for i, monster in ipairs(entities) do
      if i <= self.maxConnections then
        local entityPos = world.entityPosition(monster)
        table.insert(targeted, monster)
        if self.arcCooldownTimer == 0 then
          world.spawnProjectile("v-lightningguncurrent", entityPos, entity.id(), {0, 0}, false, {power = power, timeToLive = 0, powerMultiplier = activeItem.ownerPowerMultiplier()})
        end
      end
    end
    
    if self.arcCooldownTimer == 0 then
      self.arcCooldownTimer = self.fireTime
    end

    self:updateLightning()
    self:drawLightning(beamStart, targeted)

    coroutine.yield()
  end

  self:reset()
  animator.playSound("fireEnd")

  self.cooldownTimer = self.fireTime
  self:setState(self.winddown)
end

function TeslaStream:winddown()
  self.weapon:setStance(self.stances.winddown)
  self.weapon:updateAim()
  self.chargeTimer = self.chargeTime or 0

  local progress = 0
  util.wait(self.stances.winddown.duration, function()
    local from = self.stances.winddown.weaponOffset or {0,0}
    local to = self.stances.idle.weaponOffset or {0,0}
    self.weapon.weaponOffset = {interp.linear(progress, from[1], to[1]), interp.linear(progress, from[2], to[2])}

    self.weapon.relativeWeaponRotation = util.toRadians(interp.linear(progress, self.stances.winddown.weaponRotation, self.stances.idle.weaponRotation))
    self.weapon.relativeArmRotation = util.toRadians(interp.linear(progress, self.stances.winddown.armRotation, self.stances.idle.armRotation))

    progress = math.min(1.0, progress + (self.dt / self.stances.winddown.duration))
  end)
end

function TeslaStream:updateLightning()
  local i = 1
  while i <= #self.groundLightning do
    local lightning = self.groundLightning[i]
    if lightning.ttl <= 0 then
      table.remove(self.groundLightning, i)
    else
      lightning.ttl = lightning.ttl - self.dt
      i = i + 1
    end
  end

  if self.groundLightningTimer <= 0 then
    local gndLng = self:makeGroundLightning(self:firePosition())
    if gndLng then
      table.insert(self.groundLightning, gndLng)
    end
    self.groundLightningTimer = self.groundLightningInterval
  end
end

function TeslaStream:drawLightning(startPos, monsters)
  -- local newChain = copy(self.lightningConfig)
  -- if color then
    -- newChain.color = color
  -- end
  -- newChain.worldStartPosition = startPos
  -- newChain.worldEndPosition = endPos
  self.lightning = {}
  if monsters then
    for _, monster in ipairs(monsters) do
      local bolt = copy(self.lightningConfig)
      bolt.worldStartPosition = startPos
      bolt.worldEndPosition = world.entityPosition(monster)
      table.insert(self.lightning, bolt)
    end
  end

  for _, lng in ipairs(self.groundLightning) do
    local bolt = copy(self.groundLightningConfig)
    bolt.worldStartPosition = startPos
    bolt.worldEndPosition = lng.endPos
    table.insert(self.lightning, bolt)
  end

  activeItem.setScriptedAnimationParameter("lightning", self.lightning)
  activeItem.setScriptedAnimationParameter("lightningSeed", math.floor((os.time() + (os.clock() % 1)) * 1000))
end

function TeslaStream:makeGroundLightning(startPos)
  local collidePoint = world.lineCollision(
    startPos,
    vec2.add(
      vec2.withAngle(util.randomInRange({0, 2 * math.pi}), self.groundLightningLength),
      startPos
    )
  )
  if collidePoint then
    return {endPos = collidePoint, ttl = self.groundLightningTtl}
  end
end

function TeslaStream:damagePerShot()
  return (self.baseDamage or (self.baseDps * self.fireTime)) * (self.baseDamageMultiplier or 1.0) * config.getParameter("damageLevelMultiplier")
end

function TeslaStream:reset()
  self.weapon:setDamage()
  self.groundLightning = {}
  activeItem.setScriptedAnimationParameter("lightning", {})
  animator.stopAllSounds("fireStart")
  animator.stopAllSounds("fireLoop")
end

function TeslaStream:firePosition()
  return vec2.add(mcontroller.position(), activeItem.handPosition(self.weapon.muzzleOffset))
end

function TeslaStream:aimVector(angleAdjust)
  local aimVector = vec2.rotate({1, 0}, self.weapon.aimAngle + angleAdjust + sb.nrand(self.inaccuracy, 0))
  aimVector[1] = aimVector[1] * self.weapon.aimDirection
  return aimVector
end

function TeslaStream:uninit()
  self:reset()
end
