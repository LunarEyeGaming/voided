local oldUpdate = update or function() end

function update(dt)
  oldUpdate(dt)

  mcontroller.controlModifiers({
    gravityEnabled = false
  })

  mcontroller.setVelocity({0, 0})
end