local oldInit = init or function() end

function init()
  oldInit()

  message.setHandler("kill", projectile.die)
end