local poisonTolerance
local damageRate

function init()
  poisonTolerance = 900 -- The maximum amount of poison the player can tolerate before taking damage
  damageRate = 0.5 -- Measured in health points per poison unit per second
  damageTime = 1.0  -- Amount of time between each damage tick
  damageTimer = 0
  --poisonTolerance = 90
  --damageRate = 0.5
end

function update(dt)
  damageTimer = damageTimer - dt

  local poisonAmount = status.resource("v-depthPoison")
  if poisonAmount > poisonTolerance and damageTimer <= 0 then
    status.applySelfDamageRequest({
      damageType = "IgnoresDef",
      damage = math.floor((poisonAmount - poisonTolerance) * damageRate * damageTime),
      damageSourceKind = "poison",
      sourceEntityId = player.id()
    })
    world.sendEntityMessage(player.id(), "v-depthPoison-flash")
    damageTimer = damageTime
  end
  
  -- Display poison amount (if poisonAmount is positive)
  if poisonAmount > 0 then
    status.addEphemeralEffect("v-depthpoisonindicator")
  end
  -- world.debugText("poisonAmount: %s / %s \ndamage: %s", string.format("%.1f", poisonAmount), poisonTolerance, math.max(0, (poisonAmount - poisonTolerance) * damageRate * dt), mcontroller.position(), "green")
end