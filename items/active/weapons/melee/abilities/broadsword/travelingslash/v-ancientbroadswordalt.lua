require "/scripts/util.lua"
require "/items/active/weapons/weapon.lua"

TravelingSlash = WeaponAbility:new()

function TravelingSlash:init()
  self.cooldownTimer = self.cooldownTime
end

function TravelingSlash:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)

  self.cooldownTimer = math.max(0, self.cooldownTimer - dt)

  if self.weapon.currentAbility == nil and self.fireMode == "alt" and self.cooldownTimer == 0 and status.overConsumeResource("energy", self.energyUsage) then
    self:setState(self.windup)
  end
end

function TravelingSlash:windup()
  self.weapon:setStance(self.stances.windup)
  self.weapon:updateAim()

  util.wait(self.stances.windup.duration)

  self:setState(self.fire)
end

function TravelingSlash:fire()
  self.weapon:setStance(self.stances.fire)
  self.weapon:updateAim()

  local aimVector = self:aimVector()
  local position = vec2.add(mcontroller.position(), vec2.rotate(self.projectileOffset, vec2.angle(aimVector)))
  local params = {
    powerMultiplier = activeItem.ownerPowerMultiplier(),
    power = self:damageAmount()
  }
  world.spawnProjectile(self.projectileType, position, activeItem.ownerEntityId(), aimVector, false, params)

  animator.playSound(self:slashSound())

  util.wait(self.stances.fire.duration)
  self.cooldownTimer = self.cooldownTime
end

function TravelingSlash:slashSound()
  return self.weapon.elementalType.."TravelSlash"
end

function TravelingSlash:aimVector()
  local aimVector = vec2.rotate({1, 0}, self.weapon.aimAngle)
  aimVector[1] = aimVector[1] * mcontroller.facingDirection()
  return aimVector
end

function TravelingSlash:damageAmount()
  return self.baseDamage * config.getParameter("damageLevelMultiplier")
end

function TravelingSlash:uninit()
end
