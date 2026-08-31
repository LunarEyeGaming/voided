require "/scripts/util.lua"
require "/scripts/vec2.lua"

VWormholeAltAbility = WeaponAbility:new()

function VWormholeAltAbility:init()
  self.cooldownTimer = self.cooldownTime
end

function VWormholeAltAbility:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)

  self.cooldownTimer = math.max(0, self.cooldownTimer - dt)
  if self.weapon.currentAbility == nil and self.fireMode == "alt" and self.cooldownTimer == 0 then
    if not storage.projectileId then
      if status.overConsumeResource("energy", self.energyUsage) then
        self:setState(self.windup)
      end
    else
      self:setState(self.cancel)
    end
  end

  self:checkProjectile()
  self:updateAbilityAttributes()
end

function VWormholeAltAbility:checkProjectile()
  if storage.projectileId then
    if world.entityExists(storage.projectileId) and world.callScriptedEntity(storage.projectileId, "v_isSpacetimeRedirect") then
      self.weapon.wormholePosition = world.entityPosition(storage.projectileId)
      -- activeItem.setCameraFocusEntity(storage.projectileId)
      world.callScriptedEntity(storage.projectileId, "updateAim", activeItem.ownerAimPosition())
      animator.setAnimationState("redirectState", "redirecting")
    else
      animator.setAnimationState("redirectState", "redirectend")
      storage.projectileId = nil
      self.weapon.wormholePosition = nil
    end
  end
end

function VWormholeAltAbility:windup()
  self.weapon:setStance(self.stances.windup)

  animator.setAnimationState("redirectState", "redirect")

  util.wait(self.stances.windup.duration)

  self:setState(self.fire)
end

function VWormholeAltAbility:fire()
  self.weapon:setStance(self.stances.fire)

  local params = {}
  local aimVector = self:aimVector(self.inaccuracy or 0)
  local position = self:firePosition()
  storage.projectileId = world.spawnProjectile(self.projectileType, position, activeItem.ownerEntityId(), aimVector, false, params)

  animator.playSound("altFire")

  self.cooldownTimer = self.cooldownTime
end

function VWormholeAltAbility:cancel()
  if world.entityExists(storage.projectileId) then
    world.callScriptedEntity(storage.projectileId, "kill")
  end

  animator.playSound("altFireCancel")

  self.cooldownTimer = self.cooldownTime
end

function VWormholeAltAbility:aimVector(inaccuracy)
  local aimVector = vec2.rotate({1, 0}, self.weapon.aimAngle + sb.nrand(inaccuracy, 0))
  aimVector[1] = aimVector[1] * mcontroller.facingDirection()
  return aimVector
end

function VWormholeAltAbility:firePosition()
  return vec2.add(mcontroller.position(), activeItem.handPosition(self.weapon.muzzleOffset))
end

function VWormholeAltAbility:updateAbilityAttributes()
  if storage.projectileId and world.entityExists(storage.projectileId) then
    if not self.abilityMerged then
      self.abilityMerged = true

      util.mergeTable(self.weapon.abilities[self.mergeAbilityIndex], self.activeAbilityParameters)
      animator.setSoundPool("fire", self.activeAbilityFireSounds)
    end
  elseif self.abilityMerged then
    self.abilityMerged = false
    util.mergeTable(self.weapon.abilities[self.mergeAbilityIndex], self.inactiveAbilityParameters)

    animator.setSoundPool("fire", self.inactiveAbilityFireSounds)
  end
end

function VWormholeAltAbility:uninit()
end