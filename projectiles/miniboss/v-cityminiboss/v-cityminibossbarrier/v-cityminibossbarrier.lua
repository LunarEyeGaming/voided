require "/scripts/vec2.lua"

local lightProjectileType
local lightProjectileOffsets

local lightProjectileIds

function init()
  lightProjectileType = config.getParameter("lightProjectileType")  -- Projectile must be killable
  lightProjectileOffsets = config.getParameter("lightProjectileOffsets")
  
  lightProjectileIds = {}
  
  for _, offset in ipairs(lightProjectileOffsets) do
    local projectileId = world.spawnProjectile(lightProjectileType, vec2.add(mcontroller.position(), offset))

    table.insert(lightProjectileIds, projectileId)
  end

  message.setHandler("kill", projectile.die)
end

function destroy()
  for _, projectileId in ipairs(lightProjectileIds) do
    world.sendEntityMessage(projectileId, "kill")
  end
end