require "/scripts/util.lua"
require "/scripts/vec2.lua"
require "/scripts/poly.lua"

local angleOffset
local angles
local currentAngle
local halfFov
local sightRadius
local notFovSightRadius
local notFovOutOfSightRadius
local waitTime
local turnTime
local exposureTime

local windupTime
local beamLength
local beamCenter
local beamOffset
local beamDimensions
local damageConfig

local cameraPos
local beamCenterPos

local queriedTimings
local currentTarget

local moveState
local attackState

function init()
  -- Initialize parameters
  angleOffset = config.getParameter("angleOffset")
  angles = config.getParameter("angles")
  for i, angle in ipairs(angles) do
    angles[i] = util.toRadians(angle + angleOffset)
  end
  currentAngle = angles[1]
  halfFov = util.toRadians(config.getParameter("fov")) / 2
  sightRadius = config.getParameter("sightRadius")
  notFovSightRadius = config.getParameter("notFovSightRadius") -- sightRadius for when storage.useFov is false
  outOfSightRadius = config.getParameter("outOfSightRadius")
  notFovOutOfSightRadius = config.getParameter("notFovOutOfSightRadius")
  waitTime = config.getParameter("waitTime")
  turnTime = config.getParameter("turnTime")
  exposureTime = config.getParameter("exposureTime")

  windupTime = config.getParameter("windupTime", 0.5)
  beamLength = config.getParameter("beamLength", 50)
  beamCenter = config.getParameter("beamCenter", {2, 2})
  beamOffset = config.getParameter("beamOffset", {0, 0})
  beamDimensions = config.getParameter("beamDimensions")
  damageConfig = config.getParameter("damageConfig")
  damageConfig.damage = damageConfig.damage * root.evalFunction("monsterLevelPowerMultiplier", object.level())
  
  cameraPos = vec2.add(object.position(), animator.partPoint("base", "cameraPos"))
  beamCenterPos = vec2.add(object.position(), beamCenter)

  -- Initialize variables
  queriedTimings = {}
  currentTarget = nil

  moveState = FSM:new()
  attackState = FSM:new()
  if storage.active == nil then
    updateActive()
  elseif storage.active then
    moveState:set(states.activate)
    attackState:set(states.target)
  else
    moveState:set(states.deactivate)
    attackState:set(states.noop)
  end
  
  if storage.useFov == nil then
    updateActive()
  end
end

function update(dt)
  -- Two states: Movement and target
  moveState:update()
  attackState:update()

  -- world.debugText("currentAngle: %s\ntarget: %s\nactive: %s\nuseFov: %s", currentAngle, currentTarget, storage.active, storage.useFov, cameraPos, "green")
  -- if currentTarget then
    -- world.debugPoint(world.entityPosition(currentTarget), "blue")
  -- end
  -- if storage.useFov then
    -- world.debugPoly({
      -- cameraPos,
      -- vec2.add(cameraPos, vec2.rotate({sightRadius, 0}, currentAngle + halfFov)),
      -- vec2.add(cameraPos, vec2.rotate({sightRadius, 0}, currentAngle)),
      -- vec2.add(cameraPos, vec2.rotate({sightRadius, 0}, currentAngle - halfFov))
    -- }, "blue")
  -- end
  -- world.debugLine(cameraPos, vec2.add(cameraPos, vec2.rotate({storage.useFov and sightRadius or notFovSightRadius, 0}, currentAngle)), "green")
  --world.debugText([[halfFov: %s
--sightRadius: %s
--outOfSightRadius: %s
--waitTime: %s
--turnTime: %s
--fireInterval: %s]], halfFov, sightRadius, outOfSightRadius, waitTime, turnTime, fireInterval, vec2.add(cameraPos, {0, -7.5}), "blue")
  updateLaser()
end

function onNodeConnectionChange(args)
  updateActive()
end

function onInputNodeChange(args)
  updateActive()
end

function updateActive()
  local active = (not object.isInputNodeConnected(0)) or object.getInputNodeLevel(0)
  if active ~= storage.active then
    storage.active = active
    if active then
      moveState:set(states.activate)
      attackState:set(states.target)
    else
      moveState:set(states.deactivate)
      attackState:set(states.noop)
    end
    animator.setLightActive("flashlight", active)
    animator.setAnimationState("flashlight", active and "on" or "off")
  end

  local useFov = (not object.isInputNodeConnected(1) or object.getInputNodeLevel(1))
  if useFov ~= storage.useFov then
    storage.useFov = useFov
  end
end

-- STATES
states = {}

function states.noop()
  while true do
    coroutine.yield()
  end
end

function states.target()
  while true do
    currentTarget = getTarget()
    if currentTarget then
      attackState:set(states.windup)
    end
    coroutine.yield()
  end
end

function states.windup()
  local timer = windupTime
  local dt = script.updateDt()

  animator.setAnimationState("laser", "windup")

  while timer > 0 do
    if not hasTarget() then
      animator.setAnimationState("laser", "inactive")
      object.setDamageSources()
      attackState:set(states.target)
    end

    local aimVec
    if currentTarget and world.entityExists(currentTarget) then
      aimVec = world.distance(world.entityPosition(currentTarget), beamCenterPos)
      setAngle(vec2.angle(aimVec))
    end

    timer = timer - dt
    coroutine.yield()
  end
  
  attackState:set(states.attack)
end

function states.attack()
  animator.setAnimationState("laser", "active")

  while hasTarget() do
    local aimVec = world.distance(world.entityPosition(currentTarget), beamCenterPos)
    local targetAngle = vec2.angle(aimVec)
    local damageConfig = copy(damageConfig)

    damageConfig.poly = poly.translate(
      {
        vec2.rotate(beamOffset, targetAngle),
        vec2.rotate(vec2.add(beamOffset, {beamLength, 0}), targetAngle)
      },
      beamCenter
    )
    object.setDamageSources({damageConfig})

    setAngle(targetAngle)
    coroutine.yield()
  end
  currentTarget = nil

  animator.setAnimationState("laser", "winddown")
  object.setDamageSources()

  attackState:set(states.target)
end

function states.activate()
  while true do
    for _, angle in pairs(angles) do
      turn(angle, turnTime)
      wait()
    end
    coroutine.yield()
  end
end

function states.deactivate()
  currentTarget = nil
  animator.setAnimationState("laser", "inactive")
  turn(angles[1], turnTime)
  states.noop()
end

-- IN-COROUTINE FUNCTIONS
function wait()
  util.wait(waitTime)
end

function turn(angle, turnTime)
  local startAngle = findClosestAngle(currentAngle, angle)
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
  local queried = world.entityQuery(cameraPos, storage.useFov and sightRadius or notFovSightRadius, {withoutEntityId = entity.id(), includedTypes = {"creature"}})
  -- Iterate through each queried entity. Find the first one that is within its field of view (ordered from nearest to farthest)
  for _, qItem in pairs(queried) do
    if not storage.useFov and isValidTarget(qItem) then
      updateQueried(qItem)
      if queriedTimings[qItem] < 0 then
        return qItem
      end
    else
      local sightCloseness = math.abs(
        util.angleDiff(
          currentAngle,
          vec2.angle(world.distance(world.entityPosition(qItem), cameraPos))
        )
      )
      -- world.debugText("sightCloseness: %s", sightCloseness, vec2.add(cameraPos, {0, -3.75}), "green")
      -- world.debugText("targetAngle: %s", vec2.angle(world.distance(world.entityPosition(qItem), cameraPos)), vec2.add(cameraPos, {0, -2.5}), "green")
      if isValidTarget(qItem) and sightCloseness <= halfFov then
        updateQueried(qItem)
        if queriedTimings[qItem] < 0 then
          return qItem
        end
      end
    end
  end
end

function updateQueried(qItem)
  if queriedTimings[qItem] then
    queriedTimings[qItem] = queriedTimings[qItem] - script.updateDt()
  else
    queriedTimings[qItem] = exposureTime
  end
end

function hasTarget()
  return isValidTarget(currentTarget)
end

function isValidTarget(target)
  local outOfSightRadius = storage.useFov and outOfSightRadius or notFovOutOfSightRadius
  return world.entityExists(target) and not (world.lineTileCollision(cameraPos, world.entityPosition(target)) or world.magnitude(cameraPos, world.entityPosition(target)) > outOfSightRadius)
end

function updateLaser()
  animator.resetTransformationGroup("laser")
  -- animator.resetTransformationGroup("laserLength")
  animator.translateTransformationGroup("laser", vec2.rotate(beamOffset, currentAngle))

  -- local startPoint = vec2.add(beamCenterPos, vec2.rotate(beamOffset, currentAngle))
  -- local endPoint = vec2.add(beamCenterPos, vec2.rotate({beamOffset[1] + beamLength, beamOffset[2]}, currentAngle))
  -- local collidePoint = world.lineCollision(startPoint, endPoint)
  -- if collidePoint then
    -- endPoint = collidePoint
  -- end
  
  -- local beamLength = world.magnitude(startPoint, endPoint)
  -- animator.setGlobalTag("beamDirectives", string.format("?crop=0;0;%s;%s", math.floor(beamDimensions[1] * beamLength / beamLength), beamDimensions[2]))
  -- animator.translateTransformationGroup("laserLength", vec2.rotate({(beamLength - beamLength) / 2, 0}, currentAngle))
end

function findClosestAngle(angle, targetAngle)
  if math.abs(angle + 2 * math.pi - targetAngle) < math.abs(angle - targetAngle) then
    return angle + 2 * math.pi
  elseif math.abs(angle - 2 * math.pi - targetAngle) < math.abs(angle - targetAngle) then
    return angle - 2 * math.pi
  else
    return angle
  end
end