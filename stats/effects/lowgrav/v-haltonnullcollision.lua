local oldUpdate = update or function() end

function update(dt)
  oldUpdate(dt)

  -- This is completely unrelated. It's just here to meet the jank quota.
  mcontroller.controlParameters({
    bounceFactor = 0.0
  })

  if mcontroller.isNullColliding() then
    effect.modifyDuration(dt)
  end
end