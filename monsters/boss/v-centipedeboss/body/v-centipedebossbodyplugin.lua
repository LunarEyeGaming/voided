require "/scripts/util.lua"
require "/scripts/rect.lua"
require "/scripts/voidedattackutil.lua"

local oldInit = init or function() end
local oldUpdate = update or function() end

local attacks
local laserLength
local projectileTypeWindup

local ellipseClampDistance
local laserActivateDistance
local currentEllipseAngle
local distanceToClamped

local currentStateReset

--TODO: Address: The direction of the monster might be -1 by default. Maybe controlFace to 1.
function init()
  oldInit()

  attacks = {
    sides = states.sideProjectileGen("v-centipedepoisonshot2"),
    sides2 = states.sideProjectileGen("v-centipedeelectricshot2"),
    targeted = states.targetedProjectileGen("v-centipedepoisonshot"),
    targeted2 = states.targetedProjectileGen("v-centipedeelectricshot"),
    targeted3 = states.targetedProjectileGen("v-centipedeelectricshot", 1.0, {speed = 1, acceleration = 100}),
    laserConstrict = states.laserConstrictGen("laserpoison"),
    laserConstrict2 = states.laserConstrictGen("laserelectric"),
    laserConstrictEnd = states.laserConstrictEndGen("laserpoison"),
    laserConstrictEnd2 = states.laserConstrictEndGen("laserelectric"),
    mine = states.spawnMine
  }

  laserLength = 64
  projectileTypeWindup = "v-projectileattack1windup"

  ellipseClampDistance = 10

  laserActivateDistance = 3
  currentEllipseAngle = nil
  distanceToClamped = nil

  message.setHandler("attack", function(_, _, sourceId, attackId, targetId)
    if currentStateReset then
      currentStateReset()
    end
    state:set(attacks[attackId], sourceId, targetId)
  end)

  message.setHandler("reset", reset)

  message.setHandler("activatePhase2", activatePhase2)

  state = FSM:new()
  state:set(states.noop)
end

function update(dt)
  oldUpdate(dt)

  mcontroller.controlFace(1)

  state:update()
end

states = {}

function states.noop()
  while true do
    coroutine.yield()
  end
end

function states.sideProjectileGen(projectileType)
  return function(sourceId)
    local windupTime = 1.0
    local projectileParameters = {power = v_scaledPower(10), speed = 1, acceleration = 50,
        damageRepeatGroup = "v-centipedeboss-sideprojectile"}
    local windupParameters = {timeToLive = windupTime}

    spawnLaser({0, 1}, true, windupParameters)
    spawnLaser({0, -1}, true, windupParameters)

    animator.setAnimationState("body", "windup")

    util.wait(windupTime)

    world.spawnProjectile(
      projectileType,
      mcontroller.position(),
      entity.id(),
      vec2.rotate({0, 1}, mcontroller.rotation()),
      false,
      projectileParameters
    )

    world.spawnProjectile(
      projectileType,
      mcontroller.position(),
      entity.id(),
      vec2.rotate({0, -1}, mcontroller.rotation()),
      false,
      projectileParameters
    )

    animator.setAnimationState("body", "idle")

    notifyFinished(sourceId)

    state:set(states.noop)
  end
end

function states.targetedProjectileGen(projectileType, windupTime, projectileParameters)
  return function(sourceId, targetId)
    currentStateReset = function()
      animator.setAnimationState("targetlaser", "inactive")
      animator.setAnimationState("body", "idle")
    end

    windupTime = windupTime or 1.0

    local params = copy(projectileParameters) or {}
    params.power = v_scaledPower(params.power or 15)

    animator.setAnimationState("body", "windup")
    animator.setAnimationState("targetlaser", "active")

    -- Show laser while winding up
    util.wait(windupTime, function()
      animator.resetTransformationGroup("targetlaser")
      animator.rotateTransformationGroup("targetlaser", vec2.angle(entity.distanceToEntity(targetId)))
    end)

    -- Fire projectile at target
    entityDirection = vec2.norm(entity.distanceToEntity(targetId))

    world.spawnProjectile(
      projectileType,
      mcontroller.position(),
      entity.id(),
      entityDirection,
      false,
      params
    )

    animator.setAnimationState("targetlaser", "inactive")
    animator.setAnimationState("body", "idle")
    animator.playSound("fire")

    notifyFinished(sourceId)

    state:set(states.noop)
  end
end

function states.laserConstrictGen(laserStateName)
  return function()
    -- Unset distanceToClamped
    distanceToClamped = nil

    local dt = script.updateDt()

    local updateEllipseLaser = function()
      -- Update laser to use currentEllipseAngle, if provided.
      if currentEllipseAngle then
        animator.resetTransformationGroup("laser")
        animator.rotateTransformationGroup("laser", currentEllipseAngle)
      end
    end

    local windupTime = 3.0

    animator.setAnimationState("body", "windup")
    animator.setAnimationState(laserStateName, "windup")

    -- Wait until distanceToClamped is given, disanceToClamped is less than laserActivateDistance, and windupTime seconds
    -- have passed.
    local timer = windupTime
    while not distanceToClamped or distanceToClamped >= laserActivateDistance or timer > 0 do
      updateEllipseLaser()

      timer = timer - dt
      coroutine.yield()
    end

    animator.setAnimationState(laserStateName, "fire")

    -- Afterwards, update the laser forever. The laser stops when the laserEnd attack is triggered.
    while true do
      updateEllipseLaser()

      coroutine.yield()
    end
  end
end

function states.laserConstrictEndGen(laserStateName)
  return function(sourceId)
    animator.setAnimationState(laserStateName, "invisible")
    animator.setAnimationState("body", "idle")

    notifyFinished(sourceId)

    state:set(states.noop)
  end
end

function states.spawnMine(sourceId)
  local targetOffsetRegion = {-38, -42, 38, 42}
  local projectileType = "v-centipedeminetele"
  local projectileParameters = {
    power = v_scaledPower(15),
    targetPosition = vec2.add(rect.randomPoint(targetOffsetRegion), getCenterPosition())
  }
  local windupTime = 0.5

  animator.setAnimationState("body", "windup")

  util.wait(windupTime)

  world.spawnProjectile(projectileType, mcontroller.position(), entity.id(), {1, 0}, false, projectileParameters)

  animator.setAnimationState("body", "idle")

  notifyFinished(sourceId)

  state:set(states.noop)
end

function spawnLaser(direction, adjustToRotation, params)
  -- adjust the direction to the entity's current rotation is adjustToRotation is set to true. Don't otherwise.
  direction = adjustToRotation and vec2.rotate(direction, mcontroller.rotation()) or direction

  params.rotationCenter = mcontroller.position()

  -- Spawn the laser. It is offset by half of the laser length (adjusted to the direction)
  world.spawnProjectile(
    projectileTypeWindup,
    vec2.add(mcontroller.position(), vec2.mul(direction, laserLength / 2)),
    entity.id(),
    direction,
    true,
    params
  )
end

function getChildren()
  local children = copy(world.callScriptedEntity(self.childId, "getChildren"))

  table.insert(children, entity.id())

  return children
end

function getTail()
  return world.callScriptedEntity(self.childId, "getTail")
end

function getCenterPosition()
  return world.entityPosition(world.loadUniqueEntity("v-centerPos"))
end

function trailAlongEllipse(center, radius, clampRate)
  local ownerPos = world.entityPosition(self.ownerId)
  -- Get the angle of the vector from the center to the current position.
  local angle = vec2.angle(world.distance(mcontroller.position(), center))

  -- "Clamp" the position onto the ellipse
  local clampedPos = vec2.add(center, {radius[1] * math.cos(angle), radius[2] * math.sin(angle)})

  distanceToClamped = world.magnitude(clampedPos, mcontroller.position())

  -- If the "clamped" position is within the ellipseClampDistance value from the current position...
  if distanceToClamped < ellipseClampDistance then
    local targetAngle = vec2.angle(world.distance(clampedPos, ownerPos))
    local currentAngle = vec2.angle(world.distance(mcontroller.position(), ownerPos))

    approachAngle(ownerPos, currentAngle, targetAngle, clampRate)

    -- Make the child segment do the same.
    world.callScriptedEntity(self.childId, "trailAlongEllipse", center, radius, clampRate)
  end

  currentEllipseAngle = angle
end

---Moves the current segment for one tick along an arc from `currentAngle` to `targetAngle` (centered at `center` and
---with radius `self.segmentSize`) at a rate of `rate` radians per second.
---@param center Vec2F
---@param currentAngle number
---@param targetAngle number
---@param rate number
function approachAngle(center, currentAngle, targetAngle, rate)
  local dt = script.updateDt()

  -- Get difference between the current angle and the target angle.
  local diff = util.angleDiff(currentAngle, targetAngle)

  -- If this difference is not zero...
  if diff ~= 0 then
    -- Calculate new angle after one step based on the direction of the diff
    local newAngle = currentAngle + util.toDirection(diff) * rate * dt

    -- If the new angle overshoots the target angle...
    if util.angleDiff(newAngle, targetAngle) * diff < 0 then
      newAngle = targetAngle  -- Move it back to the target angle
    end

    -- world.debugText("direction: %s", util.toDirection(diff), mcontroller.position(), "green")
    -- world.debugLine(center, vec2.add(center, vec2.withAngle(currentAngle, self.segmentSize)), "blue")
    -- world.debugLine(center, vec2.add(center, vec2.withAngle(targetAngle, self.segmentSize)), "red")

    -- Set position to have a new angle from `center` (segmentSize distance away)
    mcontroller.setPosition(vec2.add(center, vec2.withAngle(newAngle, self.segmentSize)))
  end
end

function notifyFinished(sourceId)
  local notification = {
    sourceId = entity.id(),
    type = "finished"
  }
  world.sendEntityMessage(sourceId, "notify", notification)
end

function reset()
  animator.setGlobalTag("phase", "1")
  animator.setAnimationState("body", "idle")
  animator.setAnimationState("laserpoison", "invisible")
  animator.setAnimationState("laserelectric", "invisible")
  animator.setAnimationState("targetlaser", "inactive")
  animator.resetTransformationGroup("laser")
  animator.resetTransformationGroup("targetlaser")

  state:set(states.noop)
end

function activatePhase2()
  animator.setGlobalTag("phase", "2")
end