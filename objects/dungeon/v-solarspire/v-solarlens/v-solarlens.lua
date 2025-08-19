require "/scripts/interp.lua"
require "/scripts/util.lua"
require "/scripts/vec2.lua"

local screwedUpAngle
local fixedAngle
local adjustTime
local maxBeamLength
local damageConfig
local defaultState

local positionStart
local adjustTimer
local angleStart
local angleEnd
local currentAngle

local prevOtherLens

function init()
  screwedUpAngle = config.getParameter("screwedUpAngle", 0) * math.pi / 180
  fixedAngle = math.pi / 2
  adjustTime = config.getParameter("adjustTime", 0.5)
  maxBeamLength = config.getParameter("maxBeamLength", 100)
  damageConfig = config.getParameter("damageConfig", {damage = 0})
  damageConfig.damage = damageConfig.damage * root.evalFunction("monsterLevelPowerMultiplier", object.level())
  defaultState = config.getParameter("defaultState", false)

  positionStart = object.position()
  adjustTimer = adjustTime

  if storage.active == nil then
    setState(defaultState)
  end

  if storage.isFixed == nil then
    storage.isFixed = true
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

  object.setInteractive(not storage.isFixed)
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
  local otherLensPos = setOtherLensState(beamEnd, storage.active)

  if otherLensPos then
    local otherLensPosRelative = world.distance(otherLensPos, beamStart)
    beamEndRelative = projectVector(otherLensPosRelative, beamEndRelative)

    beamEnd = vec2.add(beamEndRelative, beamStart)
  end

  local beamMag = world.magnitude(beamEnd, beamStart)

  animator.resetTransformationGroup("lens")
  animator.rotateTransformationGroup("lens", currentAngle)

  animator.resetTransformationGroup("beam")
  animator.scaleTransformationGroup("beam", {beamMag, 1})
  animator.translateTransformationGroup("beam", {beamMag / 2, 0})

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
    orderBy = "nearest",
    callScript = "v_isSolarLens"
  })

  local entityId
  local entityPos

  if #queried > 0 then
    entityId = queried[1]

    world.callScriptedEntity(entityId, "setState", state)

    entityPos = world.entityPosition(entityId)
  end

  -- Deactivate prevOtherLens if disconnected.
  if prevOtherLens ~= entityId and prevOtherLens and world.entityExists(prevOtherLens) then
    world.callScriptedEntity(prevOtherLens, "setState", false)
  end

  prevOtherLens = queried[1]

  return entityPos
end

function getBeamEnd(angle)
  local beamStart = positionStart
  local beamEnd = vec2.add(beamStart, vec2.withAngle(angle, maxBeamLength))

  local collidePoint = world.lineCollision(beamStart, beamEnd)
  if collidePoint then
    beamEnd = collidePoint
  end

  return beamEnd
end

function updateDamageSource(beamEndRelative)
  local damagePoly = { {0, 0}, beamEndRelative }

  local damageSource = copy(damageConfig)  ---@type DamageSource
  damageSource.poly = damagePoly

  object.setDamageSources({damageSource})
end

--[[
  Returns the projection of vector `vector` onto vector `ontoVector`.

  param vector: the vector to project
  param ontoVector: the vector onto which to project
  returns: the projection of `vector` onto `ontoVector`.
]]
function projectVector(vector, ontoVector)
  return vec2.mul(
    ontoVector,
    vec2.dot(
      vector,
      ontoVector
    ) / (vec2.mag(ontoVector) ^ 2)
  )
end

function setState(state)
  storage.active = state

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