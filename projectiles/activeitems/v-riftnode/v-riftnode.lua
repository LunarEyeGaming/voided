require "/scripts/vec2.lua"

local activeProjectileType
local activeProjectileOffset
local activeProjectileDirection

function init()
  activeProjectileType = config.getParameter("activeProjectileType")
  activeProjectileOffset = config.getParameter("activeProjectileOffset", {0, 0})
  activeProjectileDirection = config.getParameter("activeProjectileDirection")
end

function update(dt)
end

function linkRift()
  local projectileId = world.spawnProjectile(
    activeProjectileType,
    vec2.add(mcontroller.position(), activeProjectileOffset),
    projectile.sourceEntity(),
    activeProjectileDirection
  )

  projectile.die()

  return projectileId
end

function v_isRiftNode()
  return true
end

function kill()
  projectile.die()
end