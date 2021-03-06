require "/scripts/util.lua"
require "/scripts/vec2.lua"

function init()
  -- Initialize parameters
  self.angularVelocity = util.toRadians(config.getParameter("angularVelocity"))
  self.currentAngle = 0
  self.halfFov = util.toRadians(config.getParameter("fov")) / 2
  self.sightRadius = config.getParameter("sightRadius")
  self.notFovSightRadius = config.getParameter("notFovSightRadius") -- sightRadius for when storage.useFov is false
  self.outOfSightRadius = config.getParameter("outOfSightRadius")
  self.notFovOutOfSightRadius = config.getParameter("notFovOutOfSightRadius")
  self.fireInterval = config.getParameter("fireInterval")
  self.exposureTime = config.getParameter("exposureTime")
  
  self.projectileType = config.getParameter("projectileType")
  self.projectileParameters = config.getParameter("projectileParameters")
  
  self.cameraPos = vec2.add(object.position(), animator.partPoint("base", "cameraPos"))

  -- Initialize variables
  self.queriedTimings = {}
  self.target = nil
  self.isAttacking = false

  self.moveState = FSM:new()
  self.attackState = FSM:new()
  if storage.active == nil then
    updateActive()
  elseif storage.active then
    self.moveState:set(states.activate)
    self.attackState:set(states.target)
  else
    self.moveState:set(states.deactivate)
    self.attackState:set(states.noop)
  end
  
  if storage.useFov == nil then
    updateActive()
  end
end

function update(dt)
  -- Two states: Movement and target
  --[[if storage.active then
    if self.target then  -- TODO: Change to use util.parallel
      if not self.isAttacking then
        self.state:set(attack)
        self.isAttacking = true
      end
    else
      self.target = getTarget()
      self.isAttacking = false
    end
  end]]
  self.moveState:update()
  self.attackState:update()

  world.debugText("currentAngle: %s\ntarget: %s\nactive: %s\nuseFov: %s", self.currentAngle, self.target, storage.active, storage.useFov, self.cameraPos, "green")
  if self.target then
    world.debugPoint(world.entityPosition(self.target), "blue")
  end
  if storage.useFov then
    world.debugPoly({
      self.cameraPos,
      vec2.add(self.cameraPos, vec2.rotate({self.sightRadius, 0}, self.currentAngle + self.halfFov)),
      vec2.add(self.cameraPos, vec2.rotate({self.sightRadius, 0}, self.currentAngle)),
      vec2.add(self.cameraPos, vec2.rotate({self.sightRadius, 0}, self.currentAngle - self.halfFov))
    }, "blue")
  end
  world.debugLine(self.cameraPos, vec2.add(self.cameraPos, vec2.rotate({storage.useFov and self.sightRadius or self.notFovSightRadius, 0}, self.currentAngle)), "green")
  --world.debugText([[halfFov: %s
--sightRadius: %s
--outOfSightRadius: %s
--waitTime: %s
--turnTime: %s
--fireInterval: %s]], self.halfFov, self.sightRadius, self.outOfSightRadius, self.waitTime, self.turnTime, self.fireInterval, vec2.add(self.cameraPos, {0, -7.5}), "blue")
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
      self.moveState:set(states.activate)
      self.attackState:set(states.target)
    else
      self.moveState:set(states.deactivate)
      self.attackState:set(states.noop)
    end
    animator.setLightActive("flashlight", active)
    --[[if active then
      storage.timer = 0
      animator.setAnimationState("trapState", "on")
      object.setLightColor(config.getParameter("activeLightColor", {0, 0, 0, 0}))
      object.setSoundEffectEnabled(true)
      animator.playSound("on");
    else
      animator.setAnimationState("trapState", "off")
      object.setLightColor(config.getParameter("inactiveLightColor", {0, 0, 0, 0}))
      object.setSoundEffectEnabled(false)
      animator.playSound("off");
    end]]
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
    self.target = getTarget()
    if self.target then
      self.attackState:set(states.attack)
    end
    coroutine.yield()
  end
end

function states.attack()
  local timer = self.fireInterval
  local dt = script.updateDt()
  while hasTarget() do
    local aimVec = world.distance(world.entityPosition(self.target), self.cameraPos)
    --setAngle(vec2.angle(aimVec))
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
  while true do
    setAngle(self.currentAngle + self.angularVelocity * script.updateDt())
    coroutine.yield()
  end
end

function states.deactivate()
  self.target = nil
  setAngle(0)
  states.noop()
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
    world.debugText("Turning", vec2.add(self.cameraPos, {0, -1.25}), "green")
  end)
end

-- FUNCTIONS

function setAngle(angle)
  self.currentAngle = angle
  animator.resetTransformationGroup("flashlights")
  animator.rotateTransformationGroup("flashlights", angle)
end

function getTarget()
  local queried = world.entityQuery(self.cameraPos, storage.useFov and self.sightRadius or self.notFovSightRadius, {withoutEntityId = entity.id(), includedTypes = {"creature"}})
  -- Iterate through each queried entity. Find the first one that is within its field of view (ordered from nearest to farthest)
  for _, qItem in pairs(queried) do
    if not storage.useFov and isValidTarget(qItem) then
      updateQueried(qItem)
      if self.queriedTimings[qItem] < 0 then
        return qItem
      end
    else
      local sightCloseness = math.abs(
        util.angleDiff(
          self.currentAngle,
          vec2.angle(world.distance(world.entityPosition(qItem), self.cameraPos))
        )
      )
      world.debugText("sightCloseness: %s", sightCloseness, vec2.add(self.cameraPos, {0, -3.75}), "green")
      world.debugText("targetAngle: %s", vec2.angle(world.distance(world.entityPosition(qItem), self.cameraPos)), vec2.add(self.cameraPos, {0, -2.5}), "green")
      if isValidTarget(qItem) and sightCloseness <= self.halfFov then
        updateQueried(qItem)
        if self.queriedTimings[qItem] < 0 then
          return qItem
        end
      end
    end
  end
end

function fire(aimVec)
  aimVec = shakeVector(aimVec, 0.05)
  world.spawnProjectile(self.projectileType, self.cameraPos, entity.id(), aimVec, false, self.projectileParameters)
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
  local outOfSightRadius = storage.useFov and self.outOfSightRadius or self.notFovOutOfSightRadius
  return world.entityExists(target) and not (world.lineTileCollision(self.cameraPos, world.entityPosition(target)) or world.magnitude(self.cameraPos, world.entityPosition(target)) > outOfSightRadius)
end