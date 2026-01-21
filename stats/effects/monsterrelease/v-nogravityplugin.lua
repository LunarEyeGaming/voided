local oldUpdate = update or function() end

function update(dt)
  oldUpdate(dt)

  if self.elapsed < self.invisibilityDuration then
    mcontroller.controlModifiers({
      gravityEnabled = false
    })

    mcontroller.setVelocity({0, 0})
  end
end