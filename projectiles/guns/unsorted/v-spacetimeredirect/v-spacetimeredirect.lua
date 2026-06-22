require "/scripts/vec2.lua"

function init()
end

function update(dt)
end

function v_isSpacetimeRedirect()
  return true
end

function kill()
  projectile.die()
end

function updateAim(position)
  local toPos = world.distance(position, mcontroller.position())
  mcontroller.setRotation(vec2.angle(toPos))
end