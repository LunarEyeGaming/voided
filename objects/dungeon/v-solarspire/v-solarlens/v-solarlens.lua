require "/scripts/interp.lua"
require "/scripts/util.lua"
require "/scripts/vec2.lua"

require "/scripts/v-ministarutil.lua"

-- Parameters
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
local beamImpactSoundInterval
local destabilizeCheckInterval

-- State variables
local positionStart
local currentBeamEnd
local currentAngle

local otherLensPollTimer
local otherLensPos
local prevReceivers
local senderId

local beamImpactSoundTimer

local lensState
local isFixed  -- Controlled by both message handlers and the state machine. Used as input into the state machine.
-- storage.isFixed is used by the update function to determine whether or not to fire a damaging beam.

-- #render_workaround: Lens beams sometimes render above other solar lenses, making them look weird. The workaround to
-- this is to shorten the beam from the sending lens and add a beam connection sprite to the receiving lens at the same
-- angle as the sending beam.

-- HOOKS

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
  beamImpactSoundInterval = config.getParameter("beamImpactSoundInterval", 0.2)

  destabilizeCheckInterval = config.getParameter("destabilizeCheckInterval", 1.0)

  otherLensPollTimer = otherLensPollInterval
  positionStart = vec2.add(object.position(), {0.001, 0.001})  -- Nudge it to avoid chunk boundary issues.
  prevReceivers = {}

  beamImpactSoundTimer = 0

  if storage.powered == nil then
    storage.powered = config.getParameter("defaultState", false)
  end

  if storage.isFixed == nil then
    storage.isFixed = config.getParameter("isFixed", true)
  end

  currentAngle = fixedAngle
  currentBeamEnd = getBeamEnd(currentAngle)

  object.setAllOutputNodes(not storage.isFixed)

  updateState()

  if decorative then
    local beamLength = config.getParameter("decorativeBeamLength", 20)
    if config.getParameter("decorativeIsConnecting", true) then
      beamLength = beamLength - 1
    end

    local connectionAngle = config.getParameter("decorativeConnectionAngle", -90) * math.pi / 180
    if connectionAngle then
      animator.resetTransformationGroup("beamconnection")
      animator.rotateTransformationGroup("beamconnection", connectionAngle)
    end

    updateAnimation(currentAngle, beamLength)
    animator.setAnimationState("beamconnection", connectionAngle and "on" or "off")
    script.setUpdateDelta(0)
  end

  message.setHandler("v-solarLens-fix", function()
    isFixed = true
  end)

  message.setHandler("v-solarLens-screwUp", function()
    isFixed = false
  end)

  message.setHandler("v-monsterwavespawner-reset", function()
    isFixed = config.getParameter("isFixed", true)
    object.setAllOutputNodes(not isFixed)
    resetZap()
    lensState:set(isFixed and states.fix or states.screwUpNoTelegraph)
  end)

  message.setHandler("v-solarLens-isFixed", function()
    return storage.isFixed
  end)

  lensState = FSM:new()
  lensState:set(storage.isFixed and states.fixed or states.waitForPortalDestabilization)
end

function update(dt)
  lensState:update()

  -- -- Zoomed out view
  -- local playerId = world.players()[1]
  -- if world.entityExists(playerId) then
  --   local playerPos = world.entityPosition(playerId)

  --   local zoomOut = function(anchor, pos, factor)
  --     local posRelative = world.distance(pos, anchor)
  --     return vec2.add(vec2.mul(posRelative, 1 / factor), anchor)
  --   end

  --   local zoomedOutStart = zoomOut(playerPos, positionStart, 16)
  --   local zoomedOutEnd = zoomOut(playerPos, currentBeamEnd, 16)
  --   world.debugPoint(zoomedOutStart, "magenta")
  --   if isActive() then
  --     world.debugLine(zoomedOutStart, zoomedOutEnd, "green")
  --   else
  --     world.debugLine(zoomedOutStart, zoomedOutEnd, "red")
  --   end
  -- end

  updateBeam(dt)
end

function die()
  if senderId and world.entityExists(senderId) then
    world.callScriptedEntity(senderId, "updateBeamEndSoon")
  else
    setBeamReceiverState(currentBeamEnd, false)
  end
end

function onNodeConnectionChange()
  if object.isInputNodeConnected(0) then
    storage.powered = object.getInputNodeLevel(0)
    updateState()
  else
    storage.powered = config.getParameter("defaultState", false)
    updateState()
  end
end

function onInputNodeChange(args)
  if args.node == 0 then
    storage.powered = args.level
    updateState()
  end
end

-- HELPER FUNCTIONS

---Sets the state of the first object that can receive beams found within the beam.
function setBeamReceiverState(beamEnd, state, angle)
  local queried = findBeamReceivers(beamEnd)

  local entityPos

  local receivers

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

  local ownId = entity.id()

  -- Control current receivers.
  local extraReceivers = {}  -- This set is for in case a lens appears in the middle of an existing beam.
  for _, entityId in ipairs(receivers) do
    local returnedReceivers = world.callScriptedEntity(entityId, "receiveBeamState", ownId, state, angle)

    -- Put receivers into set, if provided.
    if returnedReceivers then
      for _, receiverId in ipairs(returnedReceivers) do
        extraReceivers[receiverId] = true
      end
    end
  end

  -- Turn off receivers that were disconnected.
  for _, entityId in ipairs(prevReceivers) do
    if not contains(receivers, entityId) and world.entityExists(entityId) and not extraReceivers[entityId] then
      world.callScriptedEntity(entityId, "receiveBeamState", ownId, false)
    end
  end

  prevReceivers = receivers

  return entityPos
end

function findBeamReceivers(beamEnd)
  if type(positionStart) ~= "table" then
    error("positionStart is not a table. Instead, it is of type " .. type(positionStart))
  end
  if type(beamEnd) ~= "table" then
    error("beamEnd is not a table. Instead, it is of type " .. type(beamEnd) .. ". Position: " .. object.position())
  end
  local queried = world.entityLineQuery(positionStart, beamEnd, {
    withoutEntityId = entity.id(),
    includedTypes = {"object"},
    order = "nearest",
    callScript = "v_canReceiveBeams"
  })

  return queried
end

function getBeamEnd(angle)
  local beamStart = positionStart
  local aimVector = vec2.withAngle(angle)
  local beamEnd = vec2.add(beamStart, vec2.mul(aimVector, maxBeamLength))

  local collidePoint = vMinistar.lightLineTileCollision(beamStart, beamEnd, {"Block", "Slippery", "Dynamic"})

  if collidePoint then
    beamEnd = fineTuneCollidePoint(positionStart, aimVector, collidePoint)
  end

  return beamEnd, collidePoint ~= nil
end

function updateBeam(dt)
  local isCollision
  currentBeamEnd, isCollision = getBeamEnd(currentAngle)
  local beamStart = positionStart

  local beamEndRelative = world.distance(currentBeamEnd, beamStart)

  otherLensPollTimer = otherLensPollTimer - dt
  if otherLensPollTimer <= 0 then
    otherLensPos = setBeamReceiverState(currentBeamEnd, isActive(), currentAngle)

    otherLensPollTimer = otherLensPollInterval
  end

  if otherLensPos then
    local otherLensPosRelative = world.distance(otherLensPos, beamStart)
    beamEndRelative = projectVector(otherLensPosRelative, beamEndRelative)

    currentBeamEnd = vec2.add(beamEndRelative, beamStart)

    isCollision = false
  end

  -- world.debugPoint(beamEnd, "green")

  local beamMag = world.magnitude(currentBeamEnd, beamStart)
  -- See #render_workaround
  if otherLensPos then
    beamMag = beamMag - 1
  end

  -- world.debugText("%s", storage.active, object.position(), "green")

  if isCollision then
    updateAnimation(currentAngle, beamMag, dt, beamEndRelative)
  else
    updateAnimation(currentAngle, beamMag, dt)
  end

  if isActive() and not storage.isFixed then
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

function updateAnimation(currentAngle, beamMag, dt, beamImpactPos)
  animator.resetTransformationGroup("lens")
  animator.rotateTransformationGroup("lens", currentAngle)

  animator.resetTransformationGroup("beam")
  animator.scaleTransformationGroup("beam", {beamMag, 1})
  animator.translateTransformationGroup("beam", {beamMag / 2, 0})

  if beamImpactPos and isActive() then
    animator.setParticleEmitterActive("beamImpact", true)
    animator.resetTransformationGroup("beamEnd")
    animator.translateTransformationGroup("beamEnd", beamImpactPos)
    animator.setSoundPosition("beamImpact", beamImpactPos)

    beamImpactSoundTimer = beamImpactSoundTimer - dt

    if beamImpactSoundTimer <= 0 then
      animator.playSound("beamImpact")
      beamImpactSoundTimer = beamImpactSoundInterval
    end
  else
    animator.setParticleEmitterActive("beamImpact", false)
  end
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

function updateState()
  animator.setAnimationState("beam", isActive() and "on" or "off")
end

function isActive()
  return storage.active or storage.powered
end

function fineTuneCollidePoint(startPosition, aimVector, endPosition)
  -- Special cases for when the aimVector is perfectly horizontal or vertical
  if aimVector[1] == 0 or aimVector[2] == 0 then
    if aimVector[1] == 0 and aimVector[2] == 0 then
      error("fineTuneCollidePoint: aimVector is {0, 0}")
    end
    -- Perfectly vertical
    if aimVector[1] == 0 then
      if aimVector[2] < 0 then
        return {startPosition[1], endPosition[2] + 1}
      else
        return {startPosition[1], endPosition[2]}
      end
    else  -- aimVector[2] == 0
      if aimVector[1] < 0 then
        return {endPosition[1] + 1, startPosition[2]}
      else
        return {endPosition[1], startPosition[2]}
      end
    end
  end

  -- Taken from /items/active/effects/laserbeam.lua
  --When approaching the block from the right or top, the intersecting edges will be the right or top ones
  if aimVector[1] < 0 then endPosition[1] = endPosition[1] + 1 end
  if aimVector[2] < 0 then endPosition[2] = endPosition[2] + 1 end

  local blockDistance = world.distance(endPosition, startPosition)

  -- If the block's edge is in a different direction than the aim direction
  -- it is impossible to have hit that edge, make sure we draw the beam to the other edge
  if aimVector[1] * (endPosition[1] - startPosition[1]) < 0 then blockDistance[1] = 0 end
  if aimVector[2] * (endPosition[2] - startPosition[2]) < 0 then blockDistance[2] = 0 end

  -- How long does the beam need to be to move 1 block in each axis
  local deltaDistX = 1 / math.abs(aimVector[1])
  local deltaDistY = 1 / math.abs(aimVector[2])

  -- How long does the beam need to be to reach the collided block on each axis
  local distX = math.abs(blockDistance[1]) * deltaDistX
  local distY = math.abs(blockDistance[2]) * deltaDistY

  -- The largest of the distances is the length of the beam when colliding with the block
  local lineEnd = vec2.mul(aimVector, math.max(distX, distY))

  -- return endPosition
  return vec2.add(startPosition, lineEnd)
end

-- CALLSCRIPT FUNCTIONS

function v_canReceiveBeams()
  return not decorative
end

function receiveBeamState(sourceId, state, beamConnectionAngle)
  storage.active = state
  senderId = sourceId

  local beamEnd = vec2.add(positionStart, vec2.withAngle(currentAngle, maxBeamLength))
  local receivers = findBeamReceivers(beamEnd)

  -- See #render_workaround
  if beamConnectionAngle then
    animator.resetTransformationGroup("beamconnection")
    animator.rotateTransformationGroup("beamconnection", beamConnectionAngle - math.pi)
  end
  animator.setAnimationState("beamconnection", (beamConnectionAngle and state) and "on" or "off")

  updateState()

  return receivers
end

function updateBeamEndSoon()
  otherLensPollTimer = 0  -- Defer polling to next update to avoid any potential weirdness.
end

function blocksBeams()
  return true
end

-- STATE FUNCTIONS

states = {}

function states.fixed()
  isFixed = true

  while isFixed do
    coroutine.yield()
  end

  lensState:set(states.screwUp)
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

  lensState:set(states.screwedUp)
end

function states.screwUpNoTelegraph()
  storage.isFixed = false

  adjust(screwedUpAngle, screwUpTime, 0.0, preferredScrewUpDirection)

  animator.setParticleEmitterActive("telegraphSparks", false)
  animator.stopAllSounds("sparks")

  lensState:set(states.screwedUp)
end

function states.screwedUp()
  isFixed = false

  while not isFixed do
    coroutine.yield()
  end

  lensState:set(states.fix)
end

function states.fix()
  storage.isFixed = true

  adjust(fixedAngle, fixTime, 0.5, preferredFixDirection)

  lensState:set(states.fixed)
end

function states.waitForPortalDestabilization()
  local spirePortalId

  repeat
    spirePortalId = world.loadUniqueEntity("v-spireportal")

    util.wait(destabilizeCheckInterval, function()
      world.debugText("waiting for portal destabilization...", object.position(), "green")
    end)
  until spirePortalId ~= 0 and world.entityExists(spirePortalId) and world.callScriptedEntity(spirePortalId, "isDestabilized")

  lensState:set(states.screwUpNoTelegraph)
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

  animator.playSound("move", -1)

  local timer = 0
  util.wait(time, function()
    -- Offset progress by 0.5.
    local progress = (timer / time) * (1 - progressOffset) + progressOffset
    currentAngle = interp.sin(progress, angleStart, angleEnd)
    timer = timer + dt
  end)

  animator.stopAllSounds("move")
  animator.playSound("moveStop")

  currentAngle = angleEnd
end

function resetZap()
  animator.setParticleEmitterActive("telegraphSparks", false)
  animator.stopAllSounds("sparks")
  animator.setAnimationState("lens", "idle")
end