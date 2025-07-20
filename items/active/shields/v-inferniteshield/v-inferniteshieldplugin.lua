require "/scripts/vec2.lua"

local oldInit = init or function() end
local oldUpdate = update or function() end
local oldRaiseShield = raiseShield or function() end

local deflectProjectile
local deflectBaseDamage
local deflectCooldown
local deflectCooldownTimer
local deflectProjectileOffset
local deflectProjectileParameters

function init()
  oldInit()

  deflectProjectile = config.getParameter("deflectProjectile")
  deflectProjectileOffset = config.getParameter("deflectProjectileOffset", {0, 0})
  deflectBaseDamage = config.getParameter("deflectBaseDamage")
  deflectCooldown = config.getParameter("deflectCooldown")
  deflectProjectileParameters = config.getParameter("deflectProjectileParameters", {})
  deflectProjectileParameters.power = deflectBaseDamage * root.evalFunction("weaponDamageLevelMultiplier", config.getParameter("level", 1))
  deflectCooldownTimer = 0
end

function update(dt, fireMode)
  oldUpdate(dt, fireMode)

  deflectCooldownTimer = deflectCooldownTimer - dt
end

function raiseShield()
  oldRaiseShield()

  -- Extend the damage listener callback to fire a projectile on perfect block.
  local oldDamageListenerCallback = self.damageListener.callback

  self.damageListener = damageListener("damageTaken", function(notifications)
    oldDamageListenerCallback(notifications)

    if deflectCooldownTimer > 0 then
      return
    end

    for _, notification in ipairs(notifications) do
      if notification.hitType == "ShieldHit" then
        if status.resourcePositive("perfectBlock") then
          animator.playSound("deflect")

          local fireDirection = getAimVector()
          deflectProjectileParameters.powerMultiplier = activeItem.ownerPowerMultiplier()
          world.spawnProjectile(deflectProjectile, firePosition(), entity.id(), fireDirection, false, deflectProjectileParameters)

          deflectCooldownTimer = deflectCooldown

          return
        end
      end
    end
  end)
end

function firePosition()
  return vec2.add(mcontroller.position(), activeItem.handPosition(deflectProjectileOffset))
end

function getAimVector()
  local aimVector = vec2.withAngle(self.aimAngle)
  aimVector[1] = aimVector[1] * mcontroller.facingDirection()
  return aimVector
end