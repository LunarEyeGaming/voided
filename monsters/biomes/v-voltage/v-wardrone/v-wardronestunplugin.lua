local oldUpdate = update or function() end

function update(dt)
  oldUpdate(dt)

  if status.resourcePositive("stunned") then
    mcontroller.controlParameters({gravityEnabled = true})
  end
end