require "/scripts/util.lua"
require "/scripts/vec2.lua"
require "/scripts/poly.lua"

local angleOffset
local angles

local halfFov
local sightRadius
local outOfSightRadius
local waitTime
local turnTime
local exposureTime
local activationTime
local deactivationTime

local projectileType
local projectileOffset
local projectileParameters
local fireInterval
local inaccuracy

local cameraPos

local rotationCenter

local queriedTimings
local isAttacking
local target

local moveState
local attackState

function init()
  -- Initialize parameters
  angleOffset = config.getParameter("angleOffset", 0)
  angles = config.getParameter("angles")
  for i, angle in ipairs(angles) do
    angles[i] = util.toRadians(angle + angleOffset)
  end
  setAngle(angles[1])

  halfFov = util.toRadians(config.getParameter("fov", 45)) / 2
  sightRadius = config.getParameter("sightRadius", 20)
  outOfSightRadius = config.getParameter("outOfSightRadius", 40)
  waitTime = config.getParameter("waitTime", 0.5)
  turnTime = config.getParameter("turnTime", 0.5)
  exposureTime = config.getParameter("exposureTime", 0.8)
  activationTime = config.getParameter("activationTime", 0.0)
  deactivationTime = config.getParameter("deactivationTime", 0.0)
  
  projectileType = config.getParameter("projectileType")
  projectileOffset = config.getParameter("projectileOffset", {0, 0})
  projectileParameters = config.getParameter("projectileParameters")
  projectileParameters.power = (projectileParameters.power or 10) * root.evalFunction("monsterLevelPowerMultiplier", monster.level())
  fireInterval = config.getParameter("fireInterval", 0.1)
  inaccuracy = config.getParameter("inaccuracy", 0.0)
  
  cameraPos = vec2.add(mcontroller.position(), animator.partPoint("body", "cameraPos"))
  
  rotationCenter = config.getParameter("rotationCenter", {0, 0})
  
  message.setHandler("despawn", function()
    moveState:set(states.deactivate)
  end)

  -- Initialize variables
  monster.setDamageBar("none")
  queriedTimings = {}
  isAttacking = false
  target = nil
  
  script.setUpdateDelta(config.getParameter("scriptDelta", 15))

  moveState = FSM:new()
  attackState = FSM:new()

  moveState:set(states.activate)
  attackState:set(states.target)
end

function update(dt)
  -- Two states: Movement and target
  moveState:update()
  attackState:update()
end

-- STATES
states = {}

function states.noop()
  while true do
    coroutine.yield()
  end
end

function states.target()
  isAttacking = false
  
  util.wait(activationTime)

  while true do
    target = getTarget()
    if target then
      attackState:set(states.attack)
    end
    coroutine.yield()
  end
end

function states.attack()
  isAttacking = true

  local timer = 0
  local dt = script.updateDt()

  while hasTarget() do
    local aimVec = world.distance(world.entityPosition(target), cameraPos)
    setAngle(vec2.angle(aimVec))
    if timer <= 0 then
      fire(aimVec)
      timer = fireInterval
    end
    timer = timer - dt
    coroutine.yield()
  end
  target = nil
  attackState:set(states.target)
end

function states.activate()
  animator.setAnimationState("body", "appear")
  animator.setAnimationState("gun", "appear")

  util.wait(activationTime)

  -- Skip the first angle
  for i = 2, #angles do
    turn(angles[i], turnTime)
    wait()
  end
  
  moveState:set(states.deactivate)
end

function states.deactivate()
  while isAttacking do
    coroutine.yield()
  end

  turn(angles[1], turnTime)
  
  animator.setAnimationState("body", "disappear")
  animator.setAnimationState("gun", "disappear")
  
  util.wait(deactivationTime)
  
  status.setResourcePercentage("health", 0.0)
end

-- IN-COROUTINE FUNCTIONS
function wait()
  util.wait(waitTime)
end

function turn(angle, turnTime)
  local startAngle = currentAngle
  local timer = 0
  util.wait(turnTime, function(dt)
    timer = math.min(timer + dt, turnTime)
    local curAngle = util.lerp(timer / turnTime, startAngle, angle)
    setAngle(curAngle)
    -- world.debugText("Turning", vec2.add(cameraPos, {0, -1.25}), "green")
  end)
end

-- FUNCTIONS

function setAngle(angle)
  currentAngle = angle
  animator.resetTransformationGroup("gun")
  animator.rotateTransformationGroup("gun", angle)
end

function getTarget()
  local queried = world.entityQuery(cameraPos, sightRadius, {withoutEntityId = entity.id(), includedTypes = {"creature"}})
  -- Iterate through each queried entity. Find the first one that is within its field of view (ordered from nearest to farthest)
  for _, qItem in pairs(queried) do
    local sightCloseness = math.abs(
      util.angleDiff(
        currentAngle,
        vec2.angle(world.distance(world.entityPosition(qItem), cameraPos))
      )
    )
    if isValidTarget(qItem) and sightCloseness <= halfFov then
      updateQueried(qItem)
      if queriedTimings[qItem] < 0 then
        return qItem
      end
    end
  end
end

function fire(aimVec)
  animator.setAnimationState("gun", "fire")
  animator.playSound("fire")

  local angle = vec2.angle(aimVec)
  local position = vec2.add(
    mcontroller.position(), 
    vec2.add(
      vec2.rotate(projectileOffset, angle),
      rotationCenter
    )
  )

  aimVec = shakeVector(aimVec, inaccuracy)

  world.spawnProjectile(projectileType, position, entity.id(), aimVec, false, projectileParameters)
end

function shakeVector(vector, inaccuracy)
  return vec2.rotate(vector, sb.nrand(inaccuracy, 0))
end

function updateQueried(qItem)
  if queriedTimings[qItem] then
    queriedTimings[qItem] = queriedTimings[qItem] - script.updateDt()
  else
    queriedTimings[qItem] = exposureTime
  end
end

function hasTarget()
  return isValidTarget(target)
end

function isValidTarget(target)
  return world.entityExists(target) and entity.isValidTarget(target) and not (world.lineTileCollision(cameraPos, world.entityPosition(target)) or world.magnitude(cameraPos, world.entityPosition(target)) > outOfSightRadius)
end