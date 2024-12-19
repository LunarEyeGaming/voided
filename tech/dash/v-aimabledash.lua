require "/tech/doubletap.lua"
require "/scripts/vec2.lua"

local dashDirection
local dashTimer
local dashCooldownTimer
local rechargeEffectTimer
local dashControlForce
local dashSpeed
local dashDuration
local dashCooldown
local groundOnly
local stopAfterDash
local rechargeDirectives
local rechargeEffectTime
local heldUpLastTick

function init()
  dashDirection = 0
  dashTimer = 0
  dashCooldownTimer = 0
  rechargeEffectTimer = 0

  dashControlForce = config.getParameter("dashControlForce")
  dashSpeed = config.getParameter("dashSpeed")
  dashDuration = config.getParameter("dashDuration")
  dashCooldown = config.getParameter("dashCooldown")
  groundOnly = config.getParameter("groundOnly")
  stopAfterDash = config.getParameter("stopAfterDash")
  rechargeDirectives = config.getParameter("rechargeDirectives", "?fade=CCCCFFFF=0.25")
  rechargeEffectTime = config.getParameter("rechargeEffectTime", 0.1)

  animator.setAnimationState("dashing", "off")
end

function uninit()
  status.clearPersistentEffects("movementAbility")
  tech.setParentDirectives()
end

function update(args)
  if dashCooldownTimer > 0 then
    dashCooldownTimer = math.max(0, dashCooldownTimer - args.dt)
    if dashCooldownTimer == 0 then
      rechargeEffectTimer = rechargeEffectTime
      tech.setParentDirectives(rechargeDirectives)
      animator.playSound("recharge")
    end
  end

  if rechargeEffectTimer > 0 then
    rechargeEffectTimer = math.max(0, rechargeEffectTimer - args.dt)
    if rechargeEffectTimer == 0 then
      tech.setParentDirectives()
    end
  end

  if args.moves["up"]
      and not heldUpLastTick
      and dashTimer == 0
      and dashCooldownTimer == 0
      and groundValid()
      and not mcontroller.crouching()
      and not status.statPositive("activeMovementAbilities") then

    local direction = vec2.norm(world.distance(tech.aimPosition(), mcontroller.position()))
    startDash(direction)
  end
  -- doubleTap:update(args.dt, args.moves)

  if dashTimer > 0 then
    mcontroller.controlApproachVelocity(vec2.mul(dashDirection, dashSpeed), dashControlForce)
    mcontroller.controlMove(util.toDirection(dashDirection[1]), true)

    mcontroller.controlModifiers({jumpingSuppressed = true})

    mcontroller.controlDown()

    animator.setFlipped(mcontroller.facingDirection() == -1)

    dashTimer = math.max(0, dashTimer - args.dt)

    if dashTimer == 0 then
      endDash()
    end
  end

  heldUpLastTick = args.moves["up"]
end

function groundValid()
  return mcontroller.groundMovement() or not groundOnly
end

function startDash(direction)
  dashDirection = direction
  dashTimer = dashDuration
  status.setPersistentEffects("movementAbility", {{stat = "activeMovementAbilities", amount = 1}})
  animator.playSound("startDash")
  animator.setAnimationState("dashing", "on")
  animator.setParticleEmitterActive("dashParticles", true)
end

function endDash()
  status.clearPersistentEffects("movementAbility")

  if stopAfterDash then
    local movementParams = mcontroller.baseParameters()
    local currentVelocity = mcontroller.velocity()
    if vec2.mag(currentVelocity) > movementParams.runSpeed then
      mcontroller.setVelocity(vec2.mul(dashDirection, movementParams.runSpeed))
    end
    mcontroller.controlApproachVelocity(vec2.mul(dashDirection, movementParams.runSpeed), dashControlForce)
  end

  dashCooldownTimer = dashCooldown

  animator.setAnimationState("dashing", "off")
  animator.setParticleEmitterActive("dashParticles", false)
end
