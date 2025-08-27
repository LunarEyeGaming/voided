require "/scripts/interp.lua"
require "/scripts/util.lua"
require "/scripts/vec2.lua"

require "/scripts/v-ministarutil.lua"

local preScrewUpSparkTime
local preferredScrewUpDirection
local screwedUpAngle
local screwUpTime
local preferredFixDirection
local fixedAngle
local fixTime
local maxBeamLength
local damageConfig
local decorative

local positionStart
local currentAngle

local otherLensPollTimer
local otherLensPos
local prevReceivers

local materialConfigs
local state
local isFixed  -- Controlled by both message handlers and the state machine. Used as input into the state machine.
-- storage.isFixed is used by the update function to determine whether or not to fire a damaging beam.

function init()
  preScrewUpSparkTime = config.getParameter("preScrewUpSparkTime")
  preferredScrewUpDirection = config.getParameter("preferredScrewUpDirection")
  local screwedUpVector = config.getParameter("screwedUpVector")
  if screwedUpVector then
    screwedUpAngle = vec2.angle(screwedUpVector)
  else
    screwedUpAngle = config.getParameter("screwedUpAngle", 0) * math.pi / 180
  end
  screwUpTime = config.getParameter("screwUpTime", 0.5)
  preferredFixDirection = config.getParameter("preferredFixDirection")
  local fixedVector = config.getParameter("fixedVector")
  if fixedVector then
    fixedAngle = vec2.angle(fixedVector)
  else
    fixedAngle = config.getParameter("angle", 0) * math.pi / 180
  end
  fixTime = config.getParameter("fixTime", 0.5)

  maxBeamLength = config.getParameter("maxBeamLength", 100)
  damageConfig = config.getParameter("damageConfig", {damage = 0})
  otherLensPollInterval = config.getParameter("otherLensPollInterval", 0.1)
  decorative = config.getParameter("decorative", false)

  otherLensPollTimer = otherLensPollInterval
  positionStart = vec2.add(object.position(), {0.001, 0.001})  -- Nudge it to avoid chunk boundary issues.
  prevReceivers = {}

  if storage.active == nil then
    storage.active = config.getParameter("defaultState", false)
  end

  if storage.isFixed == nil then
    storage.isFixed = config.getParameter("isFixed", true)
  end

  if not storage.isFixed then
    currentAngle = screwedUpAngle
  else
    currentAngle = fixedAngle
  end

  object.setAllOutputNodes(not storage.isFixed)

  setState(storage.active)

  if decorative then
    updateAnimation(currentAngle, config.getParameter("decorativeBeamLength", 20))
    script.setUpdateDelta(0)
  end

  message.setHandler("v-solarLens-fix", function()
    isFixed = true
    object.setAllOutputNodes(false)
  end)

  message.setHandler("v-solarLens-screwUp", function()
    isFixed = false
    object.setAllOutputNodes(true)
  end)

  message.setHandler("v-monsterwavespawner-reset", function()
    isFixed = config.getParameter("isFixed", true)
    object.setAllOutputNodes(not isFixed)
    state:set(isFixed and states.fix or states.screwUpNoTelegraph)
  end)

  materialConfigs = {}
  state = FSM:new()
  state:set(storage.isFixed and states.fixed or states.screwedUp)
end

function update(dt)
  state:update()

  updateBeam(dt)
end

function die()
  local beamEnd = getBeamEnd(currentAngle)

  setBeamReceiverState(beamEnd, false)
end

---Sets the state of the first object that can receive beams found within the beam.
function setBeamReceiverState(beamEnd, state)
  local queried = world.entityLineQuery(positionStart, beamEnd, {
    withoutEntityId = entity.id(),
    includedTypes = {"object"},
    order = "nearest",
    callScript = "v_canReceiveBeams"
  })

  local entityPos

  local receivers

  -- if #queried > 0 then
  --   entityId = queried[1]

  --   local isBeamEnd = world.callScriptedEntity(entityId, "receiveBeamState", state)

  --   if isBeamEnd then
  --     entityPos = world.entityPosition(entityId)
  --   end
  -- end

  -- -- Deactivate prevOtherLens if disconnected.
  -- if prevReceivers ~= entityId and prevReceivers and world.entityExists(prevReceivers) then
  --   world.callScriptedEntity(prevReceivers, "receiveBeamState", false)
  -- end

  -- Go in order, finding the index of the first entity that is a beamEnd.
  local beamEndIndex
  for i = 1, #queried do
    local entityId = queried[i]

    local isBeamEnd = world.callScriptedEntity(entityId, "blocksBeams")
    if isBeamEnd then
      beamEndIndex = i
      break
    end
  end

  -- If one is found...
  if beamEndIndex then
    entityPos = world.entityPosition(queried[beamEndIndex])  -- Set entity position.

    -- Make receivers everything up to and including beamIndex.
    receivers = table.move(queried, 1, beamEndIndex, 1, {})
  else
    receivers = queried
  end

  -- world.debugText("receivers: %s", receivers, object.position(), "green")

  -- Control current receivers.
  for _, entityId in ipairs(receivers) do
    world.callScriptedEntity(entityId, "receiveBeamState", state)
  end

  -- Turn off receivers that were disconnected.
  for _, entityId in ipairs(prevReceivers) do
    if not contains(receivers, entityId) and world.entityExists(entityId) then
      world.callScriptedEntity(entityId, "receiveBeamState", false)
    end
  end

  prevReceivers = receivers

  return entityPos
end

function getBeamEnd(angle)
  local beamStart = positionStart
  local beamEnd = vec2.add(beamStart, vec2.withAngle(angle, maxBeamLength))

  -- local collidePoints = world.collisionBlocksAlongLine(beamStart, beamEnd, {"Block", "Slippery", "Dynamic"})

  -- for _, collideTile in ipairs(collidePoints) do
  --   local material = world.material(collideTile, "foreground")
  --   if material then
  --     local matCfg = getMaterialProperties(material)
  --     if matCfg and matCfg.isSolidAndOpaque then
  --       beamEnd = collideTile
  --       break
  --     end
  --   end
  -- end

  local collidePoint = vMinistar.lightLineTileCollision(beamStart, beamEnd, {"Block", "Slippery", "Dynamic"})

  if collidePoint then
    beamEnd = collidePoint
  end

  return beamEnd
end

function updateBeam(dt)
  -- if adjustTimer <= adjustTime then
  --   adjustTimer = adjustTimer + dt

  --   -- Offset progress by 0.5.
  --   local progress = (adjustTimer / adjustTime) * 0.5 + 0.5
  --   currentAngle = interp.sin(progress, angleStart, angleEnd)
  -- end

  local beamEnd = getBeamEnd(currentAngle)
  local beamStart = positionStart

  local beamEndRelative = world.distance(beamEnd, beamStart)

  otherLensPollTimer = otherLensPollTimer - dt
  if otherLensPollTimer <= 0 then
    otherLensPos = setBeamReceiverState(beamEnd, storage.active)

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

  if storage.active and not storage.isFixed then
    updateDamageSource(beamEndRelative)
  else
    object.setDamageSources({})
  end
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
end

function setState(state)
  animator.setAnimationState("beam", state and "on" or "off")
end

function v_canReceiveBeams()
  return not decorative
end

function receiveBeamState(state)
  storage.active = state
  setState(state)
end

function blocksBeams()
  return true
end

states = {}

function states.fixed()
  isFixed = true

  while isFixed do
    coroutine.yield()
  end

  state:set(states.screwUp)
end

function states.screwUp()
  storage.isFixed = false

  local beamEnd = getBeamEnd(screwedUpAngle)
  local beamMag = world.magnitude(beamEnd, positionStart)
  animator.setAnimationState("lens", "zap")
  animator.resetTransformationGroup("telegraphSparks")
  animator.scaleTransformationGroup("telegraphSparks", {beamMag, 1})
  animator.translateTransformationGroup("telegraphSparks", {beamMag / 2, 0})
  animator.rotateTransformationGroup("telegraphSparks", screwedUpAngle)
  animator.setParticleEmitterActive("telegraphSparks", true)
  animator.playSound("sparks", -1)
  util.wait(preScrewUpSparkTime)

  adjust(screwedUpAngle, screwUpTime, 0.0, preferredScrewUpDirection)

  animator.setParticleEmitterActive("telegraphSparks", false)
  animator.stopAllSounds("sparks")
  animator.setAnimationState("lens", "unzap")

  state:set(states.screwedUp)
end

function states.screwUpNoTelegraph()
  storage.isFixed = false

  adjust(screwedUpAngle, screwUpTime, 0.0, preferredScrewUpDirection)

  animator.setParticleEmitterActive("telegraphSparks", false)
  animator.stopAllSounds("sparks")

  state:set(states.screwedUp)
end

function states.screwedUp()
  isFixed = false

  while not isFixed do
    coroutine.yield()
  end

  state:set(states.fix)
end

function states.fix()
  storage.isFixed = true

  adjust(fixedAngle, fixTime, 0.5, preferredFixDirection)

  state:set(states.fixed)
end

function adjust(angle, time, progressOffset, preferredDirection)
  local dt = script.updateDt()
  local angleStart = currentAngle
  local angleEnd = interp.angleDiff(angleStart, angle) + angleStart
  if preferredDirection then
    -- Prefer counterclockwise but direction is clockwise.
    if preferredDirection == 1 and angleStart > angleEnd then
      angleEnd = angleEnd + 2 * math.pi
    -- Prefer clockwise but direction is counterclockwise.
    elseif preferredDirection == -1 and angleStart < angleEnd then
      angleEnd = angleEnd - 2 * math.pi
    end
  end
  local timer = 0
  util.wait(time, function()
    -- Offset progress by 0.5.
    local progress = (timer / time) * (1 - progressOffset) + progressOffset
    currentAngle = interp.sin(progress, angleStart, angleEnd)
    timer = timer + dt
  end)

  currentAngle = angleEnd
end