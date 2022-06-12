require "/scripts/util.lua"
require "/scripts/vec2.lua"
require "/scripts/poly.lua"

function init()
  -- Initialize parameters
  self.angleOffset = config.getParameter("angleOffset", 0)
  self.angles = config.getParameter("angles")
  for i, angle in ipairs(self.angles) do
    self.angles[i] = util.toRadians(angle + self.angleOffset)
  end
  setAngle(self.angles[1])
  self.halfFov = util.toRadians(config.getParameter("fov", 45)) / 2
  self.sightRadius = config.getParameter("sightRadius", 20)
  self.outOfSightRadius = config.getParameter("outOfSightRadius", 40)
  self.waitTime = config.getParameter("waitTime", 0.5)
  self.turnTime = config.getParameter("turnTime", 0.5)
  self.exposureTime = config.getParameter("exposureTime", 0.8)
  self.activationTime = config.getParameter("activationTime", 0.0)
  self.deactivationTime = config.getParameter("deactivationTime", 0.0)
  
  self.projectileType = config.getParameter("projectileType")
  self.projectileOffset = config.getParameter("projectileOffset", {0, 0})
  self.projectileParameters = config.getParameter("projectileParameters")
  self.projectileParameters.power = (self.projectileParameters.power or 10) * root.evalFunction("monsterLevelPowerMultiplier", monster.level())
  self.fireInterval = config.getParameter("fireInterval", 0.1)
  self.inaccuracy = config.getParameter("inaccuracy", 0.0)
  
  self.cameraPos = vec2.add(mcontroller.position(), animator.partPoint("body", "cameraPos"))
  
  self.rotationCenter = config.getParameter("rotationCenter", {0, 0})

  -- Initialize variables
  monster.setDamageBar("none")
  self.queriedTimings = {}
  self.isAttacking = false
  self.target = nil
  
  script.setUpdateDelta(config.getParameter("scriptDelta", 15))

  self.moveState = FSM:new()
  self.attackState = FSM:new()

  self.moveState:set(states.activate)
  self.attackState:set(states.target)
end

function update(dt)
  -- Two states: Movement and target
  self.moveState:update()
  self.attackState:update()
end

-- STATES
states = {}

function states.noop()
  while true do
    coroutine.yield()
  end
end

function states.target()
  self.isAttacking = false
  
  util.wait(self.activationTime)

  while true do
    self.target = getTarget()
    if self.target then
      self.attackState:set(states.attack)
    end
    coroutine.yield()
  end
end

function states.attack()
  self.isAttacking = true

  local timer = 0
  local dt = script.updateDt()

  while hasTarget() do
    local aimVec = world.distance(world.entityPosition(self.target), self.cameraPos)
    setAngle(vec2.angle(aimVec))
    if timer <= 0 then
      fire(aimVec)
      timer = self.fireInterval
    end
    timer = timer - dt
    coroutine.yield()
  end
  self.target = nil
  self.attackState:set(states.target)
end

function states.activate()
  animator.setAnimationState("body", "appear")
  animator.setAnimationState("gun", "appear")

  util.wait(self.activationTime)

  for _, angle in pairs(self.angles) do
    turn(angle, self.turnTime)
    wait()
  end
  
  self.moveState:set(states.deactivate)
end

function states.deactivate()
  while self.isAttacking do
    coroutine.yield()
  end

  turn(self.angles[1], self.turnTime)
  
  animator.setAnimationState("body", "disappear")
  animator.setAnimationState("gun", "disappear")
  
  util.wait(self.deactivationTime)
  
  status.setResourcePercentage("health", 0.0)
end

-- IN-COROUTINE FUNCTIONS
function wait()
  util.wait(self.waitTime)
end

function turn(angle, turnTime)
  local startAngle = self.currentAngle
  local timer = 0
  util.wait(turnTime, function(dt)
    timer = math.min(timer + dt, turnTime)
    local curAngle = util.lerp(timer / turnTime, startAngle, angle)
    setAngle(curAngle)
    -- world.debugText("Turning", vec2.add(self.cameraPos, {0, -1.25}), "green")
  end)
end

-- FUNCTIONS

function setAngle(angle)
  self.currentAngle = angle
  animator.resetTransformationGroup("gun")
  animator.rotateTransformationGroup("gun", angle)
end

function getTarget()
  local queried = world.entityQuery(self.cameraPos, self.sightRadius, {withoutEntityId = entity.id(), includedTypes = {"creature"}})
  -- Iterate through each queried entity. Find the first one that is within its field of view (ordered from nearest to farthest)
  for _, qItem in pairs(queried) do
    local sightCloseness = math.abs(
      util.angleDiff(
        self.currentAngle,
        vec2.angle(world.distance(world.entityPosition(qItem), self.cameraPos))
      )
    )
    if isValidTarget(qItem) and sightCloseness <= self.halfFov then
      updateQueried(qItem)
      if self.queriedTimings[qItem] < 0 then
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
      vec2.rotate(self.projectileOffset, angle),
      self.rotationCenter
    )
  )

  aimVec = shakeVector(aimVec, self.inaccuracy)

  world.spawnProjectile(self.projectileType, position, entity.id(), aimVec, false, self.projectileParameters)
end

function shakeVector(vector, inaccuracy)
  return vec2.rotate(vector, sb.nrand(inaccuracy, 0))
end

function updateQueried(qItem)
  if self.queriedTimings[qItem] then
    self.queriedTimings[qItem] = self.queriedTimings[qItem] - script.updateDt()
  else
    self.queriedTimings[qItem] = self.exposureTime
  end
end

function hasTarget()
  return isValidTarget(self.target)
end

function isValidTarget(target)
  return world.entityExists(target) and entity.isValidTarget(target) and not (world.lineTileCollision(self.cameraPos, world.entityPosition(target)) or world.magnitude(self.cameraPos, world.entityPosition(target)) > self.outOfSightRadius)
end