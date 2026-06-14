local exitId

function init()
  animator.setAnimationState("blink", "blinkout")
  effect.setParentDirectives("?multiply=ffffff00")
  animator.playSound("activate")
  effect.addStatModifierGroup({{stat = "activeMovementAbilities", amount = 1}, {stat = "invulnerable", amount = 1}})

  message.setHandler("v-riftlinkentrance-setExitId", function(_, _, exitId_)
    exitId = exitId_
  end)
end

function update(dt)
  -- mcontroller.setVelocity({0, 0})
  if animator.animationState("blink") == "none" then
    teleport()
  end
end

function teleport()
  if exitId and world.entityExists(exitId) then
    local teleportTarget = world.callScriptedEntity(exitId, "teleportPosition", mcontroller.collisionPoly())
    if teleportTarget then
      mcontroller.setPosition(teleportTarget)
    end
  end

  effect.setParentDirectives("")
  animator.burstParticleEmitter("translocate")
  animator.setAnimationState("blink", "blinkin")
end

function uninit()

end
