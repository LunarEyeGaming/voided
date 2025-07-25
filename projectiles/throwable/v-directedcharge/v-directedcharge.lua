local shouldDetonate = false

function init()
  message.setHandler("detonate", function()
    shouldDetonate = true
    projectile.die()
  end)

  message.setHandler("updateAim", function(_, _, aimVector)

  end)
end

function destroy()

end