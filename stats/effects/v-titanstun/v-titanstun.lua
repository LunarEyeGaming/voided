require "/scripts/status.lua"
require "/scripts/vec2.lua"

function init()
  effect.setParentDirectives("fade=332947=0.4")
  effect.addStatModifierGroup({
    {stat = "invulnerable", amount = 1},
    {stat = "fireStatusImmunity", amount = 1},
    {stat = "iceStatusImmunity", amount = 1},
    {stat = "electricStatusImmunity", amount = 1},
    {stat = "poisonStatusImmunity", amount = 1},
    {stat = "powerMultiplier", effectiveMultiplier = 0}
  })

  animator.setAnimationRate(0)
end

function update(dt)
  if status.isResource("stunned") then
    status.setResource("stunned", math.max(status.resource("stunned"), effect.duration()))
  end
  mcontroller.setVelocity({0, 0})
end