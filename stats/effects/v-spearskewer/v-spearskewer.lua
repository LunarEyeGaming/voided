function init()
  message.setHandler("v-spearskewer-updatePos", function(_, _, newPosition, knockback)
    -- If the grit is at least 1.0, do nothing.
    if status.stat("grit") >= 1.0 then
      return
    end
    local knockbackThreshold = status.stat("knockbackThreshold")
    -- If a knockback threshold is defined and the given knockback exceeds that of the threshold...
    if knockbackThreshold and knockback > knockbackThreshold then
      -- Set position
      mcontroller.setPosition(newPosition)
      mcontroller.setVelocity({0, 0})
    end
  end)

  message.setHandler("v-spearskewer-release", function()
    effect.expire()
  end)
end

function update(dt)
end