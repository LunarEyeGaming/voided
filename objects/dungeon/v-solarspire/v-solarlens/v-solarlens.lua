require "/scripts/interp.lua"
require "/scripts/util.lua"
require "/scripts/vec2.lua"

local screwedUpAngle
local fixedAngle
local adjustTime
local maxBeamLength
local damageConfig
local decorative

local positionStart
local adjustTimer
local angleStart
local angleEnd
local currentAngle

local otherLensPollTimer
local otherLensPos
local prevOtherLens

function init()
  screwedUpAngle = config.getParameter("screwedUpAngle", 0) * math.pi / 180
  fixedAngle = config.getParameter("angle", 0) * math.pi / 180
  adjustTime = config.getParameter("adjustTime", 0.0)
  maxBeamLength = config.getParameter("maxBeamLength", 100)
  damageConfig = config.getParameter("damageConfig", {damage = 0})
  otherLensPollInterval = config.getParameter("otherLensPollInterval", 0.1)
  decorative = config.getParameter("decorative", false)

  otherLensPollTimer = otherLensPollInterval
  positionStart = vec2.add(object.position(), {0.001, 0.001})  -- Nudge it to avoid chunk boundary issues.
  adjustTimer = adjustTime

  if storage.active == nil then
    storage.active = config.getParameter("defaultState", false)
  end

  if storage.isFixed == nil then
    storage.isFixed = config.getParameter("isFixed", true)
  end

  if not storage.isFixed then
    angleStart = screwedUpAngle
    angleEnd = screwedUpAngle
    currentAngle = screwedUpAngle
  else
    angleStart = fixedAngle
    angleEnd = fixedAngle
    currentAngle = fixedAngle
  end

  setState(storage.active)

  object.setInteractive(not storage.isFixed and not decorative)

  if decorative then
    updateAnimation(currentAngle, config.getParameter("decorativeBeamLength", 20))
    script.setUpdateDelta(0)
  end
end

function update(dt)
  if adjustTimer <= adjustTime then
    adjustTimer = adjustTimer + dt

    -- Offset progress by 0.5.
    local progress = (adjustTimer / adjustTime) * 0.5 + 0.5
    currentAngle = interp.sin(progress, angleStart, angleEnd)
  end

  local beamEnd = getBeamEnd(currentAngle)
  local beamStart = positionStart

  local beamEndRelative = world.distance(beamEnd, beamStart)

  otherLensPollTimer = otherLensPollTimer - dt
  if otherLensPollTimer <= 0 then
    otherLensPos = setOtherLensState(beamEnd, storage.active)

    otherLensPollTimer = otherLensPollInterval
  end

  if otherLensPos then
    local otherLensPosRelative = world.distance(otherLensPos, beamStart)
    beamEndRelative = projectVector(otherLensPosRelative, beamEndRelative)

    beamEnd = vec2.add(beamEndRelative, beamStart)
  end

  -- world.debugPoint(beamEnd, "green")

  local beamMag = world.magnitude(beamEnd, beamStart)

  -- world.debugText("%s", storage.active, object.position(), "green")

  updateAnimation(currentAngle, beamMag)

  if storage.active then
    updateDamageSource(beamEndRelative)
  else
    object.setDamageSources({})
  end
end

function onInteraction(args)
  storage.isFixed = true
  object.setInteractive(false)

  beginAdjust(fixedAngle)
end

function die()
  local beamEnd = getBeamEnd(currentAngle)

  setOtherLensState(beamEnd, false)
end

---Sets the state of the first lens found within the beam.
function setOtherLensState(beamEnd, state)
  local queried = world.entityLineQuery(positionStart, beamEnd, {
    withoutEntityId = entity.id(),
    includedTypes = {"object"},
    order = "nearest",
    callScript = "v_isSolarLens"
  })

  local entityId
  local entityPos

  if #queried > 0 then
    entityId = queried[1]

    world.callScriptedEntity(entityId, "v_solarLens_setState", state)

    entityPos = world.entityPosition(entityId)
  end

  -- Deactivate prevOtherLens if disconnected.
  if prevOtherLens ~= entityId and prevOtherLens and world.entityExists(prevOtherLens) then
    world.callScriptedEntity(prevOtherLens, "v_solarLens_setState", false)
  end

  prevOtherLens = queried[1]

  return entityPos
end

function getBeamEnd(angle)
  local beamStart = positionStart
  local beamEnd = vec2.add(beamStart, vec2.withAngle(angle, maxBeamLength))

  local collidePoint = world.lineCollision(beamStart, beamEnd, {"Block", "Slippery"})
  if collidePoint then
    beamEnd = collidePoint
  end

  return beamEnd
end

function updateDamageSource(beamEndRelative)
  local damagePoly = { {0, 0}, beamEndRelative }
  damageConfig.poly = damagePoly
  object.setDamageSources({damageConfig})
end

function updateAnimation(currentAngle, beamMag)
  animator.resetTransformationGroup("lens")
  animator.rotateTransformationGroup("lens", currentAngle)

  animator.resetTransformationGroup("beam")
  animator.scaleTransformationGroup("beam", {beamMag, 1})
  animator.translateTransformationGroup("beam", {beamMag / 2, 0})
end

--[[
  Returns the projection of vector `vector` onto vector `ontoVector`.

  param vector: the vector to project
  param ontoVector: the vector onto which to project
  returns: the projection of `vector` onto `ontoVector`.
]]
function projectVector(vector, ontoVector)
  local factor = (vector[1] * ontoVector[1] + vector[2] * ontoVector[2])
  / (ontoVector[1] * ontoVector[1] + ontoVector[2] * ontoVector[2])

  return {ontoVector[1] * factor, ontoVector[2] * factor}
  -- return vec2.mul(
  --   ontoVector,
  --   vec2.dot(
  --     vector,
  --     ontoVector
  --   ) / (vec2.mag(ontoVector) ^ 2)
  -- )
end

function setState(state)
  animator.setAnimationState("beam", state and "on" or "off")
end

function beginAdjust(angle)
  angleStart = currentAngle
  angleEnd = interp.angleDiff(angleStart, angle) + angleStart
  adjustTimer = 0.0
end

function v_isSolarLens()
  return true
end

function v_solarLens_setState(state)
  storage.active = state

  setState(state)
end