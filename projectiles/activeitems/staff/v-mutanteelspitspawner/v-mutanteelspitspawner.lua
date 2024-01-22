require "/scripts/util.lua"
require "/scripts/vec2.lua"

local projectileType
local projectileParameters
local rotationSpeed

local aimPosition

local shouldActivate

function init()
  projectileType = config.getParameter("triggerProjectileType")
  projectileParameters = config.getParameter("triggerProjectileParameters", {})
  projectileParameters.power = projectile.power()
  projectileParameters.powerMultiplier = projectile.powerMultiplier()
  rotationSpeed = 0

  aimPosition = mcontroller.position()
  
  shouldActivate = true

  message.setHandler("updateProjectile", function(_, _, aimPos)
      aimPosition = aimPos
      return entity.id()
    end)

  message.setHandler("kill", function()
    shouldActivate = false
    projectile.die()
  end)
end

function update(dt)
end

function destroy()
  if shouldActivate then
    activate()
  end
end

function activate()
  world.spawnProjectile(
      projectileType,
      mcontroller.position(),
      projectile.sourceEntity(),
      world.distance(aimPosition, mcontroller.position()),
      false,
      projectileParameters)

  projectile.processAction(projectile.getParameter("explosionAction"))
end
