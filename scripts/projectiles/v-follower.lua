local oldUpdate = update or function() end

function update(dt)
  oldUpdate(dt)

  local sourceId = projectile.sourceEntity()
  if not sourceId or not world.entityExists(sourceId) then
    return
  end
  local ownerPos = world.entityPosition(sourceId)
  mcontroller.setPosition(ownerPos)
end