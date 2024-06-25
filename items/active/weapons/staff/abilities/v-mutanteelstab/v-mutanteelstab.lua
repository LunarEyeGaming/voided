require "/scripts/vec2.lua"
require "/scripts/util.lua"

-- Melee primary ability
MeleeSlash = WeaponAbility:new()

function MeleeSlash:init()
  self.damageConfig.baseDamage = self.baseDps * self.fireTime

  self.energyUsage = self.energyUsage or 0

  self.weapon:setStance(self.stances.idle)

  self.cooldownTimer = self:cooldownTime()

  self.weapon.onLeaveAbility = function()
    self.weapon:setStance(self.stances.idle)
    status.clearPersistentEffects("movementAbility")
    status.clearPersistentEffects("knockbackImmunity")
  end
end

-- Ticks on every update regardless if this is the active ability
function MeleeSlash:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)

  self.cooldownTimer = math.max(0, self.cooldownTimer - self.dt)

  if not self.weapon.currentAbility and self.fireMode == "alt" and self.cooldownTimer == 0 and (self.energyUsage == 0 or not status.resourceLocked("energy")) then
    self:setState(self.windup)
  end
end

-- State: windup
function MeleeSlash:windup()
  self.weapon:setStance(self.stances.windup)

  if self.stances.windup.hold then
    while self.fireMode == (self.activatingFireMode or self.abilitySlot) do
      coroutine.yield()
    end
  else
    util.wait(self.stances.windup.duration)
  end

  if self.energyUsage then
    status.overConsumeResource("energy", self.energyUsage)
  end

  if self.stances.preslash then
    self:setState(self.preslash)
  else
    self:setState(self.fire)
  end
end

-- State: preslash
-- brief frame in between windup and fire
function MeleeSlash:preslash()
  self.weapon:setStance(self.stances.preslash)
  self.weapon:updateAim()

  util.wait(self.stances.preslash.duration)

  self:setState(self.fire)
end

-- State: fire
function MeleeSlash:fire()
  self.weapon:setStance(self.stances.fire)
  self.weapon:updateAim()

  animator.setAnimationState("swoosh", "fire")
  animator.playSound(self.fireSound or "fire")
  animator.burstParticleEmitter((self.elementalType or self.weapon.elementalType) .. "swoosh")
  
  status.setPersistentEffects("movementAbility", {{stat = "activeMovementAbilities", amount = 1}})
  status.setPersistentEffects("knockbackImmunity", {{stat = "knockbackThreshold", amount = 50}})

  local aimDirection = vec2.norm(world.distance(activeItem.ownerAimPosition(), mcontroller.position()))

  util.wait(self.stances.fire.duration, function()
    local damageArea = partDamageArea("swoosh")
    self.weapon:setDamage(self.damageConfig, damageArea, self.fireTime)

    -- Dash to the cursor
    mcontroller.controlApproachVelocity(vec2.mul(aimDirection, self.dashSpeed), self.dashControlForce)

    mcontroller.controlModifiers({jumpingSuppressed = true})
  end)

  -- "Halt" while still going in the direction of the dash
  local movementParams = mcontroller.baseParameters()
  local currentVelocity = mcontroller.velocity()
  if vec2.mag(currentVelocity) > movementParams.runSpeed then
    mcontroller.setVelocity(vec2.mul(aimDirection, movementParams.runSpeed))
  end
  mcontroller.controlApproachVelocity(vec2.mul(aimDirection, movementParams.runSpeed), self.dashControlForce)

  self.cooldownTimer = self:cooldownTime()
end

function MeleeSlash:cooldownTime()
  return self.fireTime - self.stances.windup.duration - self.stances.fire.duration
end

function MeleeSlash:uninit()
  self.weapon:setDamage()
  status.clearPersistentEffects("movementAbility")
  status.clearPersistentEffects("knockbackImmunity")
end
