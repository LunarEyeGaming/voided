require "/items/active/weapons/ranged/abilities/altfire.lua"

VHailstormClouds = AltFireAttack:new()

function VHailstormClouds:init()
  AltFireAttack.init(self)

  self.active = false
end

function VHailstormClouds:update(dt, fireMode, shiftHeld)
  AltFireAttack.update(self, dt, fireMode, shiftHeld)

  if self.weapon.currentAbility == self then
    if not self.active then self:activate() end
  elseif self.active then
    self:deactivate()
  end
end

function VHailstormClouds:muzzleFlash()
  --disable normal muzzle flash
end

function VHailstormClouds:activate()
  self.active = true
  animator.playSound("fireStart")
  animator.playSound("fireLoop", -1)
end

function VHailstormClouds:deactivate()
  self.active = false
  animator.stopAllSounds("fireStart")
  animator.stopAllSounds("fireLoop")
  animator.playSound("fireEnd")
end
