function init()
  mcontroller.setVelocity({0, 0})
end

function update(dt)
  if status.isResource("stunned") then
    status.setResource("stunned", math.max(status.resource("stunned"), effect.duration()))
  end
  mcontroller.controlModifiers({
      facingSuppressed = true,
      movementSuppressed = true
    })
end

function uninit()

end
