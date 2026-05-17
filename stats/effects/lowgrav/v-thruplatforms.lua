local oldUpdate = update or function() end

function update(dt)
  oldUpdate(dt)

  mcontroller.controlDown()
end