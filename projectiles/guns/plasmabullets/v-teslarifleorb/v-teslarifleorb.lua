local detonate
local detonationProjectileType
local detonationParameters

function init()
  detonate = false
  detonationProjectileType = config.getParameter("detonationProjectileType")
  detonationParameters = config.getParameter("detonationParameters", {})
  
  detonationParameters.power = detonationParameters.power or projectile.power()
  detonationParameters.powerMultiplier = detonationParameters.powerMultiplier or projectile.powerMultiplier()

  message.setHandler("v-triggerDetonation", function(_, _, power, powerMultiplier)
    detonate = true

    if power then
      detonationParameters.power = power
    end
    if powerMultiplier then
      detonationParameters.powerMultiplier = powerMultiplier
    end

    projectile.die()
  end)
end

function v_isTeslaRifleOrb()
  return true
end

function destroy()
  if detonate and detonationProjectileType then
    world.spawnProjectile(detonationProjectileType, mcontroller.position(), projectile.sourceEntity(), {0, 0}, false, detonationParameters)
  end
end