local oldUpdate = update or function() end

function update(dt)
  oldUpdate(dt)

  if not world.pointCollision(mcontroller.position()) then
    projectile.die()
  end
end