local poisonTolerance
local damageRate

function init()
  poisonTolerance = 900 -- The maximum amount of poison the player can tolerate before taking damage
  damageRate = 0.05 -- Measured in health points per poison unit per second
  --poisonTolerance = 90
  --damageRate = 0.5
end

function update(dt)
  local poisonAmount = status.resource("v-depthPoison")
  if poisonAmount > poisonTolerance then
    status.modifyResource("health", -(poisonAmount - poisonTolerance) * damageRate * dt)
  end
  world.debugText("poisonAmount: %s / %s \ndamage: %s", string.format("%.1f", poisonAmount), poisonTolerance, math.max(0, (poisonAmount - poisonTolerance) * damageRate * dt), mcontroller.position(), "green")
end