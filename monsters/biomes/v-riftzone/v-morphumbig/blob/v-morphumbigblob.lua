require "/scripts/util.lua"
require "/scripts/interp.lua"
require "/scripts/companions/capturable.lua"

local maxRadius
local expandTime
local shrinkTime
local invulnerableDistance
local maxOrbitRate
local orbitTime
local masterId
local startAngle
local tetherOffset

local state
local currentAngle
local currentRadius
local shouldDieVar

function init()
  maxRadius = config.getParameter("maxRadius")
  expandTime = config.getParameter("expandTime")
  orbitTime = config.getParameter("orbitTime")
  shrinkTime = config.getParameter("shrinkTime")
  invulnerableDistance = config.getParameter("invulnerableDistance")
  maxOrbitRate = util.toRadians(360)
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

  monster.setDamageOnTouch(true)

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

  local offset = vec2.withAngle(currentAngle, currentRadius)
  mcontroller.setPosition(vec2.add(world.entityPosition(masterId), offset))
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

function shouldDie()
  return shouldDieVar or capturable.justCaptured
end

states = {}

function states.expand()
  currentAngle = startAngle

  local timer = 0

  while timer < expandTime do
    currentRadius = interp.sin(timer / expandTime, 0, maxRadius)

    timer = timer + script.updateDt()
    coroutine.yield()
  end

  currentRadius = maxRadius

  state:set(states.orbit)
end

function states.orbit()
  local timer = 0

  while timer < orbitTime / 2 do
    local orbitRate = util.lerp(timer / orbitTime, 0, maxOrbitRate)
    currentAngle = currentAngle + orbitRate * script.updateDt()

    timer = timer + script.updateDt()
    coroutine.yield()
  end

  while timer < orbitTime do
    local orbitRate = interp.reverse(util.lerp)(timer / orbitTime, 0, maxOrbitRate)
    currentAngle = currentAngle + orbitRate * script.updateDt()

    timer = timer + script.updateDt()
    coroutine.yield()
  end

  state:set(states.shrink)
end

function states.shrink()
  local timer = 0

  while timer < shrinkTime do
    currentRadius = interp.sin(1 - timer / shrinkTime, 0, maxRadius)

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