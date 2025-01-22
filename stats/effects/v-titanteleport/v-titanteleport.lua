require "/scripts/status.lua"
require "/scripts/vec2.lua"

local freezeDuration
local freezeTimer

function init()
  freezeDuration = config.getParameter("freezeDuration")

  initialDuration = effect.duration()

  animator.setAnimationRate(0)
  if status.isResource("stunned") then
    status.setResource("stunned", math.max(status.resource("stunned"), effect.duration()))
  end

  message.setHandler("v-titanteleport-teleport", function(_, _, position)
    mcontroller.setPosition(position)
    freezeTimer = freezeDuration
    effect.addStatModifierGroup({
      {stat = "invulnerable", amount = 1},
      {stat = "fireStatusImmunity", amount = 1},
      {stat = "iceStatusImmunity", amount = 1},
      {stat = "electricStatusImmunity", amount = 1},
      {stat = "poisonStatusImmunity", amount = 1},
      {stat = "powerMultiplier", effectiveMultiplier = 0},
      {stat = "activeMovementAbilities", amount = 1}
    })
  end)
end

function update(dt)
  -- If told to freeze...
  if freezeTimer then
    freezeTimer = freezeTimer - dt
    if freezeTimer <= 0 then
      effect.expire()
      return
    end

    -- Freeze player
    mcontroller.setVelocity({0, 0})
    mcontroller.controlModifiers({
      facingSuppressed = true,
      movementSuppressed = true
    })
  end
end