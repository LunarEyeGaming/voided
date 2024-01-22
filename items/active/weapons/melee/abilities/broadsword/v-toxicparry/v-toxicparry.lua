require "/scripts/util.lua"
require "/scripts/status.lua"
require "/scripts/vec2.lua"
require "/items/active/weapons/weapon.lua"

ToxicParry = WeaponAbility:new()

function ToxicParry:init()
  self.cooldownTimer = 0
  
  self.parryProjectileParameters = self.parryProjectileParameters or {}
  self.parryProjectileParameters.power = self:leveledDamage(self.parryProjectileParameters.power or 10)
end

function ToxicParry:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)

  self.cooldownTimer = math.max(0, self.cooldownTimer - dt)

  if self.weapon.currentAbility == nil
    and fireMode == "alt"
    and self.cooldownTimer == 0
    and status.overConsumeResource("energy", self.energyUsage) then

    self:setState(self.parry)
  end
end

function ToxicParry:parry()
  self.weapon:setStance(self.stances.parry)
  self.weapon:updateAim()

  status.setPersistentEffects("broadswordParry", {{stat = "shieldHealth", amount = self.shieldHealth}})

  local blockPoly = animator.partPoly("parryShield", "shieldPoly")
  activeItem.setItemShieldPolys({blockPoly})

  animator.setAnimationState("parryShield", "active")
  animator.playSound("guard")
  
  local oldShieldHealth = status.resource("shieldStamina")

  local damageListener = damageListener("damageTaken", function(notifications)
    -- If a hit results in some shield health being lost...
    if status.resource("shieldStamina") < oldShieldHealth then
      for _,notification in pairs(notifications) do
        sb.logInfo("%s", notification)
        if notification.sourceEntityId ~= -65536 and notification.healthLost == 0 then
          animator.playSound("parry")
          animator.setAnimationState("parryShield", "block")
          if self.energyUsage and status.overConsumeResource("energy", self.energyUsage) then
            self:spawnProjectile()
          end
          return
        end
      end
    end
    oldShieldHealth = status.resource("shieldStamina")
  end)

  util.wait(self.parryTime, function(dt)
    damageListener:update()

    --Interrupt when running out of shield stamina
    if not status.resourcePositive("shieldStamina") then return true end
  end)

  self.cooldownTimer = self.cooldownTime
  activeItem.setItemShieldPolys({})
end

function ToxicParry:reset()
  animator.setAnimationState("parryShield", "inactive")
  status.clearPersistentEffects("broadswordParry")
  activeItem.setItemShieldPolys({})
end

function ToxicParry:spawnProjectile()
  world.spawnProjectile(
    self.parryProjectile,
    vec2.add(activeItem.handPosition(self.parryProjectileOffset or {0, 0}), mcontroller.position()),
    entity.id(),
    vec2.mul(self.parryProjectileDirection or {1, 0}, {mcontroller.facingDirection(), 1}),
    false,
    self.parryProjectileParameters
  )
end

function ToxicParry:leveledDamage(damage)
  return damage * (self.baseDamageMultiplier or 1.0) * config.getParameter("damageLevelMultiplier")
end

function ToxicParry:uninit()
  self:reset()
end
