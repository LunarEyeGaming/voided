local oldUpdate = update or function() end

function update(dt)
  local isStunned = status.resourcePositive("stunned")

  if not isStunned then
    oldUpdate(dt)
  end
end