local flightTime
local flightSpeed
local flightControlForce

local flightTimer
local isUsingRocketBoots
local wasUsingRocketBoots

function init()
  flightTime = config.getParameter("flightTime")
  flightSpeed = config.getParameter("flightSpeed")
  flightControlForce = config.getParameter("flightControlForce")

  refreshFuel()
end

function update(args)
  -- If the player is holding "jump" and can use rocket boots...
  if args.moves["jump"] and canUseRocketBoots() then
    useRocketBoots(args.dt)
  else
    isUsingRocketBoots = false
  end

  -- Refresh fuel upon hitting solid ground or a liquid.
  if mcontroller.groundMovement() or mcontroller.liquidMovement() then
    refreshFuel()
  end

  updateAnimation()

  -- Update wasUsingRocketBoots
  wasUsingRocketBoots = isUsingRocketBoots
end

function canUseRocketBoots()
  return flightTimer > 0
      and not mcontroller.jumping()
      and not mcontroller.canJump()
      and not mcontroller.liquidMovement()
      and not status.statPositive("activeMovementAbilities")
      and math.abs(world.gravity(mcontroller.position())) > 0
end

function useRocketBoots(dt)
  mcontroller.controlApproachYVelocity(flightSpeed, flightControlForce)
  flightTimer = flightTimer - dt
  isUsingRocketBoots = true
end

function updateAnimation()
  -- If the player just started using rocket boots...
  if isUsingRocketBoots and not wasUsingRocketBoots then
    animator.setParticleEmitterActive("thrust", true)
    animator.playSound("thrustStart")
    animator.playSound("thrustLoop", -1)
  -- Otherwise, if the player just stopped using rocket boots...
  elseif not isUsingRocketBoots and wasUsingRocketBoots then
    animator.setParticleEmitterActive("thrust", false)
    animator.stopAllSounds("thrustStart")
    animator.stopAllSounds("thrustLoop")
    animator.playSound("thrustEnd")
  end
end

function refreshFuel()
  flightTimer = flightTime
end