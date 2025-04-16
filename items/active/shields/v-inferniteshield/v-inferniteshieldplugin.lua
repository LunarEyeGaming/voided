require "/scripts/vec2.lua"

local oldRaiseShield = raiseShield or function() end

local deflectProjectile
local deflectBaseDamage
local deflectProjectileParameters

function raiseShield()
  oldRaiseShield()

  -- Extend the damage listener callback to fire a projectile on perfect block.
  local oldDamageListenerCallback = self.damageListener.callback

  self.damageListener = damageListener("damageTaken", function(notifications)
    oldDamageListenerCallback(notifications)

    for _, notification in ipairs(notifications) do
      if notification.hitType == "ShieldHit" then
        if status.resourcePositive("perfectBlock") then
          local fireDirection = getAimVector()

          world.spawnProjectile("fireplasmarocket", mcontroller.position(), entity.id(), fireDirection, false, {
            power = 100,
            powerMultiplier = activeItem.ownerPowerMultiplier(),
            speed = 100,
            acceleration = 0
          })
        end
      end
    end
  end)
end

function getAimVector()
  local aimVector = vec2.withAngle(self.aimAngle)
  aimVector[1] = aimVector[1] * mcontroller.facingDirection()
  return aimVector
end