local oldUpdate = update or function() end

function update(dt)
  oldUpdate(dt)

  if projectile.timeToLive() > 0.5 then
    projectile.setTimeToLive(1.5)
  end
end