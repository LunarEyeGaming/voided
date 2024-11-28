function init()
end

function update(dt)
  if projectile.timeToLive() > 0.5 then
    projectile.setTimeToLive(1.5)
  end
end