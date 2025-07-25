local targetOffsetPos

function init()
  message.setHandler("v-spearskewer-updatePos", function(_, _, newPosition, knockback)
    -- If the grit is at least 1.0, do nothing.
    if status.stat("grit") >= 1.0 then
      return
    end
    local knockbackThreshold = status.stat("knockbackThreshold")
    -- If a knockback threshold is defined and the given knockback exceeds that of the threshold...
    if knockbackThreshold and knockback > knockbackThreshold then
      targetOffsetPos = newPosition
    end
  end)

  message.setHandler("v-spearskewer-release", function()
    effect.expire()
  end)

  script.setUpdateDelta(1)
end

function update(dt)
  local sourceEntityPos = world.entityPosition(effect.sourceEntity())

  -- If the source entity exists and the target offset position is defined...
  if sourceEntityPos and targetOffsetPos then
    -- Get absolute position
    local targetPos = {sourceEntityPos[1] + targetOffsetPos[1], sourceEntityPos[2] + targetOffsetPos[2]}

    -- If the position is not inside of a block...
    if not world.pointCollision(targetPos) then
      world.debugText("Test", targetPos, "blue")
      -- Set the position.
      mcontroller.setPosition(targetPos)
      mcontroller.setVelocity({0, 0})
    end
  end
end