require "/scripts/vec2.lua"

require "/scripts/projectiles/v-mergergeneric.lua"

local mergeHandlerKind
local ownerId

function init()
  mergeHandlerKind = config.getParameter("mergeHandlerKind")
  ownerId = projectile.sourceEntity()

  vMergeHandler.set(mergeHandlerKind)
end

function update(dt)
  if not (ownerId and world.entityExists(ownerId)) then
    projectile.die()
  end
end

function teleportPosition(collidePoly)
  local resolvedPoint = world.resolvePolyCollision(collidePoly, vec2.add(mcontroller.position(), config.getParameter("teleportOffset")), config.getParameter("teleportTolerance"))
  if resolvedPoint then
    return resolvedPoint
  else
    return false
  end
end

function kill()
  projectile.die()
end
