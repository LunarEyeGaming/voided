local gravityModifier
local movementParams
local goThroughPlatforms
local trailMinYVelocity
local trailMaxYVelocity
local newGravityMultiplier

function init()
  gravityModifier = config.getParameter("gravityModifier")
  movementParams = mcontroller.baseParameters()
  goThroughPlatforms = config.getParameter("goThroughPlatforms")
  trailMinYVelocity = config.getParameter("trailMinYVelocity")
  trailMaxYVelocity = config.getParameter("trailMaxYVelocity")

  setGravityMultiplier()

  animator.setParticleEmitterActive("trail", true)
end

function setGravityMultiplier()
  local oldGravityMultiplier = movementParams.gravityMultiplier or 1

  newGravityMultiplier = gravityModifier * oldGravityMultiplier
end

function update(dt)
  mcontroller.controlParameters({
     gravityMultiplier = newGravityMultiplier
  })

  -- Keep effect from expiring while in null areas.
  if mcontroller.isNullColliding() then
    effect.modifyDuration(dt)
  end

  if goThroughPlatforms then
    mcontroller.controlDown()
  end

  local yVelocity = mcontroller.yVelocity()
  local trailEnabled = (not trailMinYVelocity or trailMinYVelocity <= yVelocity) and
  (not trailMaxYVelocity or yVelocity <= trailMaxYVelocity)
  animator.setParticleEmitterActive("trail", trailEnabled)
end

function uninit()

end
