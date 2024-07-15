require "/scripts/vec2.lua"
require "/scripts/util.lua"

local followRadius
local followSpeed
local followControlForce
local timeToLiveRange

local sourceEntity
local queryParams

function init()
  followRadius = config.getParameter("followRadius")
  followSpeed = config.getParameter("followSpeed")
  followControlForce = config.getParameter("followControlForce")
  timeToLiveRange = config.getParameter("timeToLiveRange")
  
  projectile.setTimeToLive(util.randomInRange(timeToLiveRange))

  sourceEntity = projectile.sourceEntity()
  queryParams = {
    withoutEntityId = sourceEntity,
    includedTypes = {"creature"},
    order = "nearest"
  }
  
  if not sourceEntity then
    projectile.die()
  end
end

function update(dt)
  local pos = mcontroller.position()
  local queried = world.entityQuery(pos, followRadius, {includedTypes = {"creature"}})
  
  for _, entityId in ipairs(queried) do
    if world.entityCanDamage(sourceEntity, entityId) then
      local entPos = world.entityPosition(entityId)
      if not world.lineTileCollision(pos, entPos) then
        local toTarget = vec2.norm(world.distance(entPos, pos))
        
        mcontroller.approachVelocity(vec2.mul(toTarget, followSpeed), followControlForce)
        
        break
      end
    end
  end
end