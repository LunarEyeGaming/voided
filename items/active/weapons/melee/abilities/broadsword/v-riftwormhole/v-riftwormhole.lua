require "/scripts/util.lua"
require "/scripts/rect.lua"
require "/items/active/weapons/weapon.lua"

VRiftWormhole = WeaponAbility:new()

function VRiftWormhole:init()
  self.cooldownTimer = self.cooldownTime
end

function VRiftWormhole:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)

  self.cooldownTimer = math.max(0, self.cooldownTimer - dt)

  if self.weapon.currentAbility == nil and self.fireMode == "alt" and self.cooldownTimer == 0 then
    if not storage.projectileId then
      self:setState(self.windupNode)
    else
      if shiftHeld then
        self:setState(self.windupCancelNode)
      elseif not status.statPositive("activeMovementAbilities")
          and status.overConsumeResource("energy", self.energyUsage) then
        self:setState(self.windupLink)
      end
    end
  end

  self:checkProjectile()
end

function VRiftWormhole:checkProjectile()
  if storage.projectileId
      and not (world.entityExists(storage.projectileId) and world.callScriptedEntity(storage.projectileId, "v_isRiftNode")) then

    storage.projectileId = nil
  end
end

function VRiftWormhole:windupNode()
  self.weapon:setStance(self.stances.windupNode)

  util.wait(self.stances.windupNode.duration)

  self:setState(self.fireNode)
end

function VRiftWormhole:fireNode()
  self.weapon:setStance(self.stances.fireNode)

  local params = {}
  storage.projectileId = self:spawnProjectile(self.nodeProjectileType, self.nodeProjectileOffset, params)

  animator.playSound("riftNode")

  util.wait(self.stances.fireNode.duration)
  self.cooldownTimer = self.cooldownTime
end

function VRiftWormhole:windupCancelNode()
  self.weapon:setStance(self.stances.windupCancelNode)

  util.wait(self.stances.windupCancelNode.duration)

  self:setState(self.fireCancelNode)
end

function VRiftWormhole:fireCancelNode()
  self.weapon:setStance(self.stances.fireCancelNode)

  world.callScriptedEntity(storage.projectileId, "kill")

  animator.playSound("riftCancelNode")

  util.wait(self.stances.fireCancelNode.duration)
end

function VRiftWormhole:windupLink()
  self.weapon:setStance(self.stances.windupLink)

  util.wait(self.stances.windupLink.duration)

  self:setState(self.fireLink)
end

function VRiftWormhole:fireLink()
  self.weapon:setStance(self.stances.fireLink)

  local exitId = world.callScriptedEntity(storage.projectileId, "linkRift")
  local params = {
    linkingNode = exitId
  }

  self.linkProjectileId = self:spawnProjectile(self.linkProjectileType, self.linkProjectileOffset, params)

  status.addEphemeralEffect(self.teleportStatusEffect)
  world.sendEntityMessage(activeItem.ownerEntityId(), "v-riftlinkentrance-setExitId", exitId)

  animator.playSound("riftLink")

  self:setState(self.followUp)
end

function VRiftWormhole:followUp()
  local firedPrimary = false

  util.wait(self.stances.fireLink.duration)
  self.cooldownTimer = self.cooldownTime

  util.wait(self.followUpGracePeriod, function()
    if not self.linkProjectileId or not world.entityExists(self.linkProjectileId) then
      return true
    end

    if self.fireMode == "primary" then
      firedPrimary = true
      return true
    end
  end)

  if firedPrimary and status.overConsumeResource("energy", self.energyUsage) then
    local params = {
      powerMultiplier = activeItem.ownerPowerMultiplier(),
      power = self:damageAmount()
    }
    self:spawnProjectile(self.followUpProjectileType, self.followUpProjectileOffset, params)
  end
end

function VRiftWormhole:spawnProjectile(projectile, offset, params)
  local aimVector = self:aimVector()
  local position = vec2.add(self:projectileCenter(), vec2.mul(offset, {mcontroller.facingDirection(), 1}))
  return world.spawnProjectile(projectile, position, activeItem.ownerEntityId(), aimVector, false, params)
end

function VRiftWormhole:aimVector()
  local aimVector = {mcontroller.facingDirection(), 0}
  return aimVector
end

function VRiftWormhole:damageAmount()
  return self.baseDamage * config.getParameter("damageLevelMultiplier")
end

function VRiftWormhole:uninit()
end

function VRiftWormhole:projectileCenter()
  if self.accountForCrouching then
    return rect.center(rect.translate(mcontroller.boundBox(), mcontroller.position()))
  else
    return mcontroller.position()
  end
end
