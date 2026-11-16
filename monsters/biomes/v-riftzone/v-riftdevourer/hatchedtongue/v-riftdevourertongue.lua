require "/scripts/util.lua"
require "/scripts/interp.lua"
require "/scripts/companions/capturable.lua"

local maxRadius
local expandTime
local shrinkTime
local invulnerableDistance
local latchTime
local latchRadius
local masterId
local startAngle
local tetherOffset

local state
local currentAngle
local currentRadius
local shouldDieVar
local latchToEntity

function init()
  maxRadius = config.getParameter("maxRadius")
  expandTime = config.getParameter("expandTime")
  latchTime = config.getParameter("latchTime")
  shrinkTime = config.getParameter("shrinkTime")
  invulnerableDistance = config.getParameter("invulnerableDistance")
  latchRadius = config.getParameter("latchRadius")
  masterId = config.getParameter("masterId")
  startAngle = vec2.angle(config.getParameter("aimVector", {1, 0}))
  if not masterId or not world.entityExists(masterId) then
    shouldDieVar = true
    return
  end

  status.setStatusProperty("headId", masterId)

  capturable.init()

  message.setHandler("pet.attemptCapture", function(_,_,...)
    return world.callScriptedEntity(masterId, "capturable.attemptCapture", ...)
  end)

  state = FSM:new()
  state:set(states.expand)

  shouldDieVar = false

  monster.setAnimationParameter("chains", config.getParameter("chains"))

  status.addEphemeralEffect("invulnerable")

  initTether()
end

function update(dt)
  mcontroller.controlFace(1)

  capturable.update(dt)

  if not masterId or not world.entityExists(masterId) then
    shouldDieVar = true
    return
  end

  local distance = world.magnitude(mcontroller.position(), world.entityPosition(masterId))
  if distance <= invulnerableDistance then
    status.addEphemeralEffect("invulnerable")
  else
    status.removeEphemeralEffect("invulnerable")
  end

  state:update(dt)

  updateTether(dt)
end

function initTether()
  tetherOffset = config.getParameter("tetherConfig.offset", {0, 0})
end

function updateTether(dt)
  if not masterId or not world.entityExists(masterId) then
    return
  end

  local tetherPosition = world.entityPosition(masterId)
  local tetherStart = vec2.add(mcontroller.position(), tetherOffset)
  local tetherDistance = world.distance(tetherPosition, tetherStart)
  local tetherLength = vec2.mag(tetherDistance)
  local tetherAngle = vec2.angle(tetherDistance)

  animator.resetTransformationGroup("tether")
  animator.scaleTransformationGroup("tether", {tetherLength, 1})
  animator.rotateTransformationGroup("tether", tetherAngle, tetherOffset)
end

function setAngleMagPosition()
  local offset = vec2.withAngle(currentAngle, currentRadius)
  mcontroller.setPosition(vec2.add(world.entityPosition(masterId), offset))
end

function findLatchEntity()
  local queried = world.entityQuery(mcontroller.position(), latchRadius, {includedTypes = {"creature"}})
  for _, entityId in ipairs(queried) do
    if world.entityCanDamage(masterId, entityId) then
      return entityId
    end
  end
end

function shouldDie()
  return shouldDieVar or capturable.justCaptured
end

states = {}

function states.expand()
  currentAngle = startAngle

  local timer = 0

  while timer < expandTime do
    currentRadius = interp.sin(timer / expandTime, 0, maxRadius)

    setAngleMagPosition()
    latchToEntity = findLatchEntity()
    if latchToEntity then
      state:set(states.latch)
      return
    end

    timer = timer + script.updateDt()
    coroutine.yield()
  end

  currentRadius = maxRadius

  state:set(states.shrink)
end

function states.shrink()
  local timer = 0

  while timer < shrinkTime do
    currentRadius = interp.sin(1 - timer / shrinkTime, 0, maxRadius)

    setAngleMagPosition()
    latchToEntity = findLatchEntity()
    if latchToEntity then
      state:set(states.latch)
      return
    end

    timer = timer + script.updateDt()
    coroutine.yield()
  end

  state:set(states.die)
end

function states.latch()
  monster.setDamageOnTouch(true)

  local timer = 0
  while timer < latchTime and latchToEntity and world.entityExists(latchToEntity) do
    mcontroller.setPosition(world.entityPosition(latchToEntity))

    timer = timer + script.updateDt()
    coroutine.yield()
  end

  local startDistance = world.magnitude(mcontroller.position(), world.entityPosition(masterId))
  currentAngle = vec2.angle(world.distance(mcontroller.position(), world.entityPosition(masterId)))

  timer = 0
  while timer < shrinkTime do
    currentRadius = interp.linear(1 - timer / shrinkTime, 0, startDistance)

    setAngleMagPosition()

    timer = timer + script.updateDt()
    coroutine.yield()
  end

  state:set(states.die)
end

function states.die()
  shouldDieVar = true

  while true do
    coroutine.yield()
  end
end