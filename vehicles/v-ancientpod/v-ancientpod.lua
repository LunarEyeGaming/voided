require "/scripts/util.lua"
require "/scripts/voidedutil.lua"

function initShip()
  self.moveSpeed = config.getParameter("moveSpeed")
  self.airForce = config.getParameter("airForce")
  self.height = 0
  
  self.movementSettings = config.getParameter("movementSettings")
  self.occupiedMovementSettings = config.getParameter("occupiedMovementSettings")

  self.protection = config.getParameter("protection")
  self.maxHealth = config.getParameter("health")
  self.maxEnergy = config.getParameter("energy")

  storage.health = storage.health or self.maxHealth
  storage.energy = storage.energy or self.maxEnergy
  
  self.projectileSpecs = config.getParameter("projectileSpecs")
  self.beamSpecs = config.getParameter("beamSpecs")
  self.energyUsages = config.getParameter("energyUsages")
  
  self.fireInterval = config.getParameter("fireInterval", 0.1)
  self.ringRotationFactor = config.getParameter("ringRotationFactor", 1)

  self.driving = false
  self.lastDriver = nil
  
  self.facingDirection = 1

  self.firing = false
  self.firingAlt = false
  
  self.fireState = FSM:new()
  self.altFireState = FSM:new()
  
  self.fireState:set(states.idle)
  self.altFireState:set(states.idle)

  storage.ammo = storage.ammo or 20
  
  self.ringAngle = 0
end

function updateShip(dt, driver, moveDir)

  if storage.health <= 0 then
    animator.burstParticleEmitter("damageShards")
    animator.playSound("explode")
    vehicle.destroy()
  end

  if mcontroller.atWorldLimit() then
    vehicle.destroy()
    return
  end

  if driver then
    if self.lastDriver == nil and hasEnergy() then
      animator.playSound("engineStart")
    end

    if driver == 0 then
      vehicle.setDamageTeam({type = "passive"})
    else
      vehicle.setDamageTeam(world.entityDamageTeam(driver))
    end
    if hasEnergy() then
      mcontroller.applyParameters(self.occupiedMovementSettings)
    else
      mcontroller.applyParameters(self.movementSettings)
    end
    vehicle.setInteractive(false)
  
    -- Passive energy drainage
    consumeEnergy(self.energyUsages.passive * dt)
    
    updateRing(dt)
  else
    vehicle.setDamageTeam({type = "passive"})
    mcontroller.applyParameters(self.movementSettings)
    vehicle.setInteractive(true)
  end
  self.lastDriver = driver

  local driving = vec2.mag(moveDir) > 0.0
  if driving and not self.driving then
    animator.playSound("engineLoop", -1)
  elseif not driving then
    animator.stopAllSounds("engineLoop", 0.5)
  end
  self.driving = driving

  if driver then
    moveDir = vec2.norm(moveDir)
    mcontroller.approachVelocity(vec2.mul(moveDir, self.moveSpeed), self.airForce)
  else
    mcontroller.rotate(-mcontroller.rotation() * dt)
  end

  -- Run firing coroutines
  self.fireState:update()
  self.altFireState:update()
  
  -- Consume energy
  if self.driving then
    consumeEnergy(self.energyUsages.move * dt)
  end
  
  if self.firing then
    consumeEnergy(self.energyUsages.fire * dt)
  end
  
  if self.firingAlt then
    consumeEnergy(self.energyUsages.altFire * dt)
  end
  
  world.debugText("Health: %s / %s\nEnergy: %s / %s", storage.health, self.maxHealth, storage.energy, self.maxEnergy, mcontroller.position(), "green")
  
  updateDisplays()
end

function shipHeight()
  return self.height
end

function toggleBlinds()
  if animator.animationState("blinds") == "closed" then
    animator.setAnimationState("blinds", "open")
  elseif animator.animationState("blinds") == "opened" then
    animator.setAnimationState("blinds", "close")
  end
end

function isFiring()
  return self.firing
end

function startFiring()
  self.firing = true
  self.fireState:set(states.fire)
end

function stopFiring()
  self.firing = false
  self.fireState:set(states.idle)
end

function isFiringAlt()
  return self.firingAlt
end

function startFiringAlt()
  self.firingAlt = true
  self.altFireState:set(states.altFire)
end

function stopFiringAlt()
  self.firingAlt = false
  self.altFireState:set(states.altFireStop)
end

function applyDamage(damageRequest)
  local damage = 0
  if damageRequest.damageType == "Damage" then
    damage = damage + root.evalFunction2("protection", damageRequest.damage, self.protection)
  elseif damageRequest.damageType == "IgnoresDef" then
    damage = damage + damageRequest.damage
  else
    return {}
  end

  local healthLost = math.min(damage, storage.health)
  storage.health = storage.health - healthLost

  return {{
    sourceEntityId = damageRequest.sourceEntityId,
    targetEntityId = entity.id(),
    position = mcontroller.position(),
    damageDealt = damage,
    healthLost = healthLost,
    hitType = "Hit",
    damageSourceKind = damageRequest.damageSourceKind,
    targetMaterialKind = "stone",
    killed = storage.health <= 0
  }}
end

function consumeEnergy(amount)
  local energyLost = math.min(amount, storage.energy)
  storage.energy = storage.energy - energyLost
end

function hasEnergy()
  return storage.energy > 0
end

function updateDisplays()
  updateCircleBar("healthL", "healthR", storage.health, self.maxHealth)
  updateCircleBar("energyL", "energyR", storage.energy, self.maxEnergy)
end

function updateRing(dt)
  local velocity = mcontroller.velocity()
  local angularVelocity = vec2.mag(velocity) * self.ringRotationFactor * util.toDirection(velocity[1])
  self.ringAngle = util.wrapAngle(self.ringAngle + angularVelocity * dt)
  animator.resetTransformationGroup("ring")
  animator.rotateTransformationGroup("ring", self.ringAngle)
end

-- STATES

states = {}

function states.idle()
  while true do
    coroutine.yield()
  end
end

function states.fire()
  local useFront = true

  while true do
    local aimPosition = vehicle.aimPosition("seat")

    if useFront then
      animator.setAnimationState("frontcannon", "fire")

      local fireOffset = animator.partPoint("frontcannon", "fireOffset")
      local firePosition = vec2.add(mcontroller.position(), fireOffset)
      world.spawnProjectile(self.projectileSpecs.type, firePosition, entity.id(), world.distance(aimPosition, firePosition), self.projectileSpecs.config)

      useFront = false
    else
      animator.setAnimationState("backcannon", "fire")

      local fireOffset = animator.partPoint("backcannon", "fireOffset")
      local firePosition = vec2.add(mcontroller.position(), fireOffset)
      world.spawnProjectile(self.projectileSpecs.type, firePosition, entity.id(), world.distance(aimPosition, firePosition), self.projectileSpecs.config)

      useFront = true
    end

    animator.playSound("fire")
    util.wait(self.fireInterval)
  end
end

function states.altFire()
  animator.setAnimationState("beam", "active")
  animator.setAnimationState("beamcannon", "fire")

  while true do
    local ownPosition = mcontroller.position()
    local aimVector = vec2.norm(world.distance(vehicle.aimPosition("seat"), ownPosition))
    local fireOffset = animator.partPoint("beamcannon", "fireOffset")
    self.firePosition = vec2.add(ownPosition, fireOffset)

    local collidePoint = world.lineCollision(self.firePosition, vec2.add(vec2.mul(aimVector, self.beamSpecs.length), self.firePosition))
    local beamLength = self.beamSpecs.length
    if collidePoint then
      world.damageTileArea(collidePoint, self.beamSpecs.damageRadius, "foreground", ownPosition, "beamish", self.beamSpecs.damageAmount, 99)
      beamLength = world.magnitude(self.firePosition, collidePoint)
    end
    updateBeam(beamLength)
    animator.resetTransformationGroup("beamcannon")
    animator.rotateTransformationGroup("beamcannon", vec2.angle(aimVector))
    coroutine.yield()
  end
end

function states.altFireStop()
  animator.setAnimationState("beam", "inactive")
  animator.setAnimationState("beamcannon", "idle")
  states.idle()
end

function updateBeam(beamLength)
  animator.resetTransformationGroup("beam")
  animator.scaleTransformationGroup("beam", {beamLength, 1}, {self.beamSpecs.sourceOffset[1], self.beamSpecs.sourceOffset[2] - self.beamSpecs.height / 2})

  --local particleRegion = {self.beamSourceOffset[1], self.beamSourceOffset[2], self.beamSourceOffset[1] + beamLength, self.beamSourceOffset[2]}
  --animator.setParticleEmitterOffsetRegion("beam", particleRegion)
end