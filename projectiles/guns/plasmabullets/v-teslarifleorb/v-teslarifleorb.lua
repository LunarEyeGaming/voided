require "/scripts/projectiles/v-mergergeneric.lua"

local detonationProjectileType
local detonationParameters

function init()
  detonationProjectileType = config.getParameter("detonationProjectileType")
  detonationParameters = config.getParameter("detonationParameters", {})

  detonationParameters.power = detonationParameters.power or projectile.power()
  detonationParameters.powerMultiplier = detonationParameters.powerMultiplier or projectile.powerMultiplier()

  vMergeHandler.set("v-teslarifleorb", false, function(_, power, powerMultiplier)
    if power then
      detonationParameters.power = power
    end
    if powerMultiplier then
      detonationParameters.powerMultiplier = powerMultiplier
    end

    return true
  end)
end

function destroy()
  if vMergeHandler.isMerged and detonationProjectileType then
    world.spawnProjectile(detonationProjectileType, mcontroller.position(), projectile.sourceEntity(), {0, 0}, false, detonationParameters)
  end
end