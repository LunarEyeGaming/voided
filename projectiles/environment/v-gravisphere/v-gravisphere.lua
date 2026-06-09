local maxDistance
local sourceId

function init()
  maxDistance = config.getParameter("maxDistance")
  sourceId = projectile.sourceEntity()
end

function update(dt)
  if not sourceId or not world.entityExists(sourceId) or world.magnitude(world.entityPosition(sourceId), mcontroller.position()) > maxDistance then
    projectile.die()
  end
end