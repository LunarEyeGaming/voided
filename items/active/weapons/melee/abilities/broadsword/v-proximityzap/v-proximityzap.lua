require "/items/active/weapons/weapon.lua"
require "/scripts/util.lua"
require "/scripts/voidedutil.lua"

ProximityZap = WeaponAbility:new()

function ProximityZap:init()
  self.cooldownTimer = self.cooldownTime
end

function ProximityZap:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)

  self.cooldownTimer = math.max(0, self.cooldownTimer - dt)

  if self.weapon.currentAbility == nil and self.fireMode == "alt" and self.cooldownTimer == 0 and status.overConsumeResource("energy", self.energyUsage) then
    self:setState(self.windup)
  end
end

function ProximityZap:windup()
  self.weapon:setStance(self.stances.windup)
  self.weapon:updateAim()

  util.wait(self.stances.windup.duration)

  self:setState(self.fire)
end

function ProximityZap:fire()
  self.weapon:setStance(self.stances.fire)
  self.weapon:updateAim()
  
  local endPositions = self:attack()

  animator.playSound(self:slashSound())

  local timer = 0
  util.wait(self.stances.fire.duration, function(dt)
    local color = voidedUtil.lerpColor(timer / self.stances.fire.duration, self.lightningConfig.startColor, self.lightningConfig.endColor)
    self:drawLightning(endPositions, color)
    timer = timer + dt
  end)
  
  -- Clear lightning
  activeItem.setScriptedAnimationParameter("lightning", {})
  self.cooldownTimer = self.cooldownTime
end

function ProximityZap:attack()
  local lightningEndPositions = {}
  local sourcePos = self:queryPosition()
  local queried = world.entityQuery(sourcePos, self.shockRadius, {includedTypes = {"monster", "npc"}})
  for _, entityId in ipairs(queried) do
    local entityPos = world.nearestTo(sourcePos, world.entityPosition(entityId))
    local entCollidePoint = world.lineCollision(sourcePos, entityPos)
    if not entCollidePoint then
      world.spawnProjectile("v-lightningguncurrent", entityPos, entity.id(), {0, 0}, false, {power = self:damageAmount(), timeToLive = 0, powerMultiplier = activeItem.ownerPowerMultiplier()})
      table.insert(lightningEndPositions, entityPos)
    end
  end
  
  for i = 1, self.extraLightningCount do
    local offset = vec2.withAngle(util.randomInRange({0, 2 * math.pi}), util.randomInRange({1, self.shockRadius}))
    local extraPos = vec2.add(sourcePos, offset)
    local collidePoint = world.lineCollision(sourcePos, extraPos)
    if collidePoint then
      table.insert(lightningEndPositions, collidePoint)
    else
      table.insert(lightningEndPositions, extraPos)
    end
  end

  return lightningEndPositions
end

function ProximityZap:shockPosition()
  return vec2.add(mcontroller.position(), activeItem.handPosition(animator.partPoint("lightningPoint", "lightningPoint")))
end

function ProximityZap:queryPosition()
  return vec2.add(mcontroller.position(), {self.queryOffset[1] * mcontroller.facingDirection(), self.queryOffset[2]})
end

function ProximityZap:slashSound()
  return "proximityZap"
end

function ProximityZap:damageAmount()
  return self.baseDamage * config.getParameter("damageLevelMultiplier")
end

function ProximityZap:drawLightning(endPositions, color)
  local lightning = {}
  for _, pos in ipairs(endPositions) do
    local bolt = copy(self.lightningConfig)
    bolt.worldStartPosition = self:shockPosition()
    bolt.worldEndPosition = pos
    bolt.color = color
    table.insert(lightning, bolt)
  end

  activeItem.setScriptedAnimationParameter("lightning", lightning)
  activeItem.setScriptedAnimationParameter("lightningSeed", math.floor((os.time() + (os.clock() % 1)) * 1000))
end

function ProximityZap:uninit()
end