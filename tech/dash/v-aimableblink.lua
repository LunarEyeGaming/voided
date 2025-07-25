require "/scripts/vec2.lua"
require "/scripts/util.lua"

local dashCooldownTimer
local blinkDashCooldownTimer
local rechargeEffectTimer
local dashControlForce
local dashSpeed
local dashDuration
local dashCooldown
local groundOnly
local stopAfterDash
local rechargeDirectives
local rechargeEffectTime

local blinkDistance
local blinkOutTime
local blinkInTime
local blinkCooldown

local traceStepSize
local traceParticle

local dashState

function init()
  dashCooldownTimer = 0
  rechargeEffectTimer = 0
  blinkDashCooldownTimer = 0

  dashControlForce = config.getParameter("dashControlForce")
  dashSpeed = config.getParameter("dashSpeed")
  dashDuration = config.getParameter("dashDuration")
  dashCooldown = config.getParameter("dashCooldown")
  groundOnly = config.getParameter("groundOnly")
  stopAfterDash = config.getParameter("stopAfterDash")
  rechargeDirectives = config.getParameter("rechargeDirectives", "?fade=CCCCFFFF=0.25")
  rechargeEffectTime = config.getParameter("rechargeEffectTime", 0.1)

  blinkDistance = config.getParameter("blinkDistance")
  blinkOutTime = config.getParameter("blinkOutTime")
  blinkInTime = config.getParameter("blinkInTime")
  blinkCooldown = config.getParameter("blinkCooldown")

  traceStepSize = config.getParameter("traceStepSize", 0.8)
  traceParticle = config.getParameter("traceParticle", "energyblade")

  animator.setAnimationState("dashing", "off")

  dashState = FSM:new()
  dashState:set(states.inactive)
end

function uninit()
  status.clearPersistentEffects("movementAbility")
  tech.setParentDirectives()
end

function update(args)
  if blinkDashCooldownTimer > 0 then
    blinkDashCooldownTimer = math.max(0, blinkDashCooldownTimer - args.dt)
    -- if blinkDashCooldownTimer == 0 then
    --   rechargeEffectTimer = rechargeEffectTime
    --   tech.setParentDirectives(rechargeDirectives)
    --   animator.playSound("rechargeBlink")
    -- end
    if blinkDashCooldownTimer == 0 and dashCooldownTimer == 0 then
      rechargeEffectTimer = rechargeEffectTime
      tech.setParentDirectives(rechargeDirectives)
      animator.playSound("rechargeBlink")
    end
  end

  if dashCooldownTimer > 0 then
    dashCooldownTimer = math.max(0, dashCooldownTimer - args.dt)
    if dashCooldownTimer == 0 then
      rechargeEffectTimer = rechargeEffectTime
      tech.setParentDirectives(rechargeDirectives)
      if blinkDashCooldownTimer == 0 then
        animator.playSound("rechargeBlink")
      else
        animator.playSound("recharge")
      end
    end
  end

  if rechargeEffectTimer > 0 then
    rechargeEffectTimer = math.max(0, rechargeEffectTimer - args.dt)
    if rechargeEffectTimer == 0 then
      tech.setParentDirectives()
    end
  end

  dashState:resume(args)
end

function groundValid()
  return mcontroller.groundMovement() or not groundOnly
end

function startDash()
  status.setPersistentEffects("movementAbility", {{stat = "activeMovementAbilities", amount = 1}})
  animator.playSound("startDash")
  animator.setAnimationState("dashing", "on")
  animator.setParticleEmitterActive("dashParticles", true)
end

function endDash(direction)
  status.clearPersistentEffects("movementAbility")

  if stopAfterDash then
    local movementParams = mcontroller.baseParameters()
    local currentVelocity = mcontroller.velocity()
    if vec2.mag(currentVelocity) > movementParams.runSpeed then
      mcontroller.setVelocity(vec2.mul(direction, movementParams.runSpeed))
    end
    mcontroller.controlApproachVelocity(vec2.mul(direction, movementParams.runSpeed), dashControlForce)
  end

  dashCooldownTimer = dashCooldown

  animator.setAnimationState("dashing", "off")
  animator.setParticleEmitterActive("dashParticles", false)
end

function startBlinkDash()
  mcontroller.setVelocity({0, 0})
  -- tech.setToolUsageSuppressed(true)
  animator.playSound("startBlinkDash")
  animator.setAnimationState("dashing", "blinkOut")
  -- Set activeMovementAbilities flag
  status.setPersistentEffects("movementAbility", {{stat = "activeMovementAbilities", amount = 1}})
  status.addPersistentEffect("v-blinkInvulnerability", {stat = "invulnerable", amount = 1})  -- Make invulnerable
end

function endBlinkDash()
  -- tech.setToolUsageSuppressed(false)
  status.clearPersistentEffects("movementAbility")
  status.clearPersistentEffects("v-blinkInvulnerability")

  dashCooldownTimer = math.max(0, dashCooldown - blinkInTime)
  blinkDashCooldownTimer = blinkCooldown
end

function findBlinkTargetPosition(direction)
  local stepDistance = 0.2
  local traceStep = math.floor(traceStepSize / stepDistance + 0.5)  -- Number of stepDistance units to go through before placing a trace marker.

  local blinkPos = mcontroller.position()

  -- Move in the provided direction in steps, resolving poly collisions as necessary. Also trace the path using
  -- particles.
  for i = 0, blinkDistance / stepDistance do
    blinkPos = vec2.add(blinkPos, vec2.mul(direction, stepDistance))
    blinkPos = world.resolvePolyCollision(mcontroller.collisionPoly(), blinkPos, 2, {"Null", "Block", "Dynamic", "Slippery"})
    if i % traceStep == 0 then
      world.spawnProjectile("v-proxyprojectile", blinkPos, nil, {0, 0}, false, {actionOnReap = {{action = "particle", specification = traceParticle}}})
    end
  end

  return blinkPos
end

states = {}

function states.inactive()
  local args = coroutine.yield()  -- Get args for current tick

  local heldUpLastTick = false
  -- Wait until the right conditions are met for dashing.
  while not (args.moves["up"]  -- The player has tapped...
  and not heldUpLastTick  -- ...but not held, the "up" movement key
  and dashCooldownTimer == 0  -- The dash is not in cooldown
  and groundValid()  -- The player is on the ground or can dash in the air
  and not mcontroller.crouching()  -- The player is not crouching
  and not status.statPositive("activeMovementAbilities")) do  -- No current movement abilities are active.
    heldUpLastTick = args.moves["up"]

    args = coroutine.yield()  -- Get args for next tick.
  end
  local direction = vec2.norm(world.distance(tech.aimPosition(), mcontroller.position()))

  if blinkDashCooldownTimer == 0 then
    dashState:set(states.blinkDash, direction)
  else
    dashState:set(states.normalDash, direction)
  end
end

function states.normalDash(direction)
  startDash()

  util.wait(dashDuration, function()
    -- Dash in current direction
    mcontroller.controlApproachVelocity(vec2.mul(direction, dashSpeed), dashControlForce)
    mcontroller.controlMove(util.toDirection(direction[1]), true)

    mcontroller.controlModifiers({jumpingSuppressed = true})  -- No jumping

    mcontroller.controlDown()  -- Go through platforms

    animator.setFlipped(mcontroller.facingDirection() == -1)
  end)

  endDash(direction)

  dashState:set(states.inactive)
end

function states.blinkDash(direction)
  local blinkPos = findBlinkTargetPosition(direction)
  startBlinkDash()

  util.wait(blinkOutTime, function()
    tech.setParentDirectives("?multiply=00000000")
    mcontroller.setVelocity({0, 0})
  end)

  mcontroller.setPosition(blinkPos)
  tech.setParentDirectives()
  animator.setAnimationState("dashing", "blinkIn")

  util.wait(blinkInTime, function()
    mcontroller.setVelocity({0, 0})
  end)

  endBlinkDash()

  dashState:set(states.inactive)
end