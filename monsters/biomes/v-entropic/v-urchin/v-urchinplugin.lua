require "/scripts/vec2.lua"

local oldInit = init or function() end
local oldUpdate = update or function() end

local tetherDirection
local tetherMaxInitialLength
local tetherOffset
local tetherPreferredMinLength
local tetherPreferredMaxLength
local tetherAdjustSpringForce

local tetherPosition

local driftPeriod
local driftAmplitude
local driftControlForce
local driftTimer

function init()
  oldInit()

  initTether()

  initDrift()
end

function update(dt)
  oldUpdate(dt)

  updateTether(dt)

  updateDrift(dt)
end

function initTether()
  tetherDirection = vec2.norm(config.getParameter("tetherConfig.direction", {1, 0}))
  tetherMaxInitialLength = config.getParameter("tetherConfig.maxInitialLength")
  tetherOffset = config.getParameter("tetherConfig.offset", {0, 0})
  tetherPreferredMinLength = config.getParameter("tetherConfig.preferredMinLength")
  tetherPreferredMaxLength = config.getParameter("tetherConfig.preferredMaxLength")
  tetherAdjustSpringForce = config.getParameter("tetherConfig.adjustSpringForce")
  local startPos = vec2.add(mcontroller.position(), tetherOffset)

  local tetherEnd = vec2.add(startPos, vec2.mul(tetherDirection, tetherMaxInitialLength))

  tetherPosition = world.lineCollision(startPos, tetherEnd)

  if not tetherPosition then
    status.setResourcePercentage("health", 0.0)
    mcontroller.setPosition({0, 0})
    script.setUpdateDelta(0)
    return
  end
end

function updateTether(dt)
  local tetherStart = vec2.add(mcontroller.position(), tetherOffset)
  local tetherDistance = world.distance(tetherPosition, tetherStart)
  local tetherLength = vec2.mag(tetherDistance)
  local tetherAngle = vec2.angle(tetherDistance)

  animator.resetTransformationGroup("tether")
  animator.scaleTransformationGroup("tether", {tetherLength, 1})
  animator.rotateTransformationGroup("tether", tetherAngle, tetherOffset)

  tetherSpringForce(tetherLength, tetherDistance)
end

function tetherSpringForce(tetherLength, tetherDistance)
  local currentTetherDirection = vec2.norm(tetherDistance)
  if tetherLength > tetherPreferredMaxLength then
    local adjustDistance = tetherLength - tetherPreferredMaxLength
    local tetherForce = vec2.mul(currentTetherDirection, tetherAdjustSpringForce * adjustDistance)
    mcontroller.controlForce(tetherForce)
  elseif tetherLength < tetherPreferredMinLength then
    local adjustDistance = tetherLength - tetherPreferredMinLength
    local tetherForce = vec2.mul(currentTetherDirection, tetherAdjustSpringForce * adjustDistance)
    mcontroller.controlForce(tetherForce)
  end
end

function initDrift()
  driftPeriod = config.getParameter("driftConfig.period")
  driftAmplitude = config.getParameter("driftConfig.amplitude")
  driftControlForce = config.getParameter("driftConfig.controlForce")
  driftTimer = math.random() * driftPeriod  -- Random phase shift
end

function updateDrift(dt)
  driftTimer = (driftTimer + dt) % driftPeriod

  local driftVelocity = driftAmplitude * math.cos(2 * math.pi * driftTimer / driftPeriod)

  mcontroller.controlApproachXVelocity(driftVelocity, driftControlForce)
end