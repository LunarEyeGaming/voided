require "/scripts/vec2.lua"

local oldInit = init or function() end
local oldUpdate = update or function() end

local attractRadius
local attractSpeed
local attractForce

function init()
  oldInit()

  attractRadius = config.getParameter("attractRadius")
  attractSpeed = config.getParameter("attractSpeed")
  attractForce = config.getParameter("attractForce")
end

function update(dt)
  oldUpdate(dt)

  local ownPos = mcontroller.position()

  local queried = world.entityQuery(ownPos, attractRadius, {includedTypes = {"projectile"}})
  for _, projectileId in ipairs(queried) do
    world.sendEntityMessage(projectileId, "v-meteorwand-attract", ownPos, attractSpeed, attractForce)
  end
end