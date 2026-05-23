local oldUpdate = update or function() end

function update(dt)
  oldUpdate(dt)

  if mcontroller.isNullColliding() then
    effect.modifyDuration(dt)
  end
end