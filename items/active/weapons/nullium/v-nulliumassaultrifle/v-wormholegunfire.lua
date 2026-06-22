require "/items/active/weapons/ranged/gunfire.lua"

-- Wormhole fire ability
VWormholeGunFire = GunFire:new()

function VWormholeGunFire:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)

  self.cooldownTimer = math.max(0, self.cooldownTimer - self.dt)

  if animator.animationState("firing") ~= "fire" then
    animator.setLightActive("muzzleFlash", false)
  end

  if self.fireMode == (self.activatingFireMode or self.abilitySlot)
    and not self.weapon.currentAbility
    and self.cooldownTimer == 0
    and not status.resourceLocked("energy")
    and not self:firePositionIsBlocked() then

    if self.fireType == "auto" and status.overConsumeResource("energy", self:energyPerShot()) then
      self:setState(self.auto)
    elseif self.fireType == "burst" then
      self:setState(self.burst)
    end
  end
end

function VWormholeGunFire:firePositionIsBlocked()
  return not self.weapon.wormholePosition and world.lineTileCollision(mcontroller.position(), self:firePosition())
end

function VWormholeGunFire:firePosition()
  return self.weapon.wormholePosition or vec2.add(mcontroller.position(), activeItem.handPosition(self.weapon.muzzleOffset))
end

function VWormholeGunFire:aimVector(inaccuracy)
  if self.weapon.wormholePosition then
    local toPosition = world.distance(activeItem.ownerAimPosition(), self.weapon.wormholePosition)
    local angle = vec2.angle(toPosition)
    local aimVector = vec2.rotate({1, 0}, angle + sb.nrand(inaccuracy, 0))
    return aimVector
  end

  return GunFire.aimVector(self, inaccuracy)
end