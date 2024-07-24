require "/scripts/util.lua"
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
-- local ellipseClampSpeed
-- local currentEllipseClampVelocity

local currentStateReset

function init()
  oldInit()

  attacks = {
    sides = states.sideProjectile,
    targeted = states.targetedProjectile,
    laserConstrict = states.laserConstrict,
    laserConstrictEnd = states.laserConstrictEnd
  }

  laserLength = 64
  projectileTypeWindup = "v-projectileattack1windup"

  ellipseClampDistance = 10

  laserActivateDistance = 3
  currentEllipseAngle = nil
  distanceToClamped = nil
  -- ellipseClampSpeed = 100
  -- ellipseClampControlForce = 250
  -- currentEllipseClampVelocity = {0, 0}

  message.setHandler("attack", function(_, _, sourceId, attackId, targetId)
    if currentStateReset then
      currentStateReset()
    end
    state:set(attacks[attackId], sourceId, targetId)
  end)

  state = FSM:new()
  state:set(states.noop)
end

function update(dt)
  oldUpdate(dt)

  state:update()
end

states = {}

function states.noop()
  while true do
    coroutine.yield()
  end
end

function states.sideProjectile(sourceId)
  local projectileType = "v-ancientphaseshot"
  local windupTime = 1.0
  local projectileParameters = {power = v_scaledPower(10), speed = 1, acceleration = 50}
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

function states.targetedProjectile(sourceId, targetId)
  currentStateReset = function()
    animator.setAnimationState("targetlaser", "inactive")
    animator.setAnimationState("body", "idle")
  end

  local projectileType = "v-ancientsniperturretshot"
  local projectileParameters = {power = v_scaledPower(15), speed = 150, movementSettings = {collisionEnabled = false}}
  local windupTime = 1.0

  animator.setAnimationState("body", "windup")
  animator.setAnimationState("targetlaser", "active")

  util.wait(windupTime, function()
    animator.resetTransformationGroup("targetlaser")
    -- Must flip... for some reason.
    animator.rotateTransformationGroup("targetlaser", math.pi - vec2.angle(entity.distanceToEntity(targetId)))
  end)

  entityDirection = vec2.norm(entity.distanceToEntity(targetId))

  world.spawnProjectile(
    projectileType,
    mcontroller.position(),
    entity.id(),
    entityDirection,
    false,
    projectileParameters
  )

  animator.setAnimationState("targetlaser", "inactive")
  animator.setAnimationState("body", "idle")
  animator.playSound("fire")

  notifyFinished(sourceId)

  state:set(states.noop)
end

function states.laserConstrict(sourceId)
  -- Unset distanceToClamped
  distanceToClamped = nil

  local dt = script.updateDt()

  local updateEllipseLaser = function()
    -- Update laser to use currentEllipseAngle, if provided. I have no idea why I have to horizontally flip it first.
    if currentEllipseAngle then
      local angleFlipped = math.pi - currentEllipseAngle
      animator.resetTransformationGroup("laser")
      animator.rotateTransformationGroup("laser", angleFlipped)
    end
  end

  local windupTime = 3.0

  animator.setAnimationState("body", "windup")
  animator.setAnimationState("laser", "windup")

  -- Wait until distanceToClamped is given, disanceToClamped is less than laserActivateDistance, and windupTime seconds
  -- have passed.
  local timer = windupTime
  while not distanceToClamped or distanceToClamped >= laserActivateDistance or timer > 0 do
    updateEllipseLaser()

    timer = timer - dt
    coroutine.yield()
  end

  animator.setAnimationState("laser", "fire")

  -- Afterwards, update the laser forever. The laser stops when the laserEnd attack is triggered.
  while true do
    updateEllipseLaser()

    coroutine.yield()
  end
end

function states.laserConstrictEnd(sourceId)
  animator.setAnimationState("laser", "invisible")
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

function trailAlongEllipse(center, radius, clampRate)
  local ownerPos = world.entityPosition(self.ownerId)
  -- Get the angle of the vector from the center to the current position.
  local angle = vec2.angle(world.distance(mcontroller.position(), center))

  --world.debugLine(center, mcontroller.position(), "yellow")

  -- "Clamp" the position onto the ellipse
  local clampedPos = vec2.add(center, {radius[1] * math.cos(angle), radius[2] * math.sin(angle)})

  distanceToClamped = world.magnitude(clampedPos, mcontroller.position())

  -- If the "clamped" position is within the ellipseClampDistance value from the current position...
  if distanceToClamped < ellipseClampDistance then
    -- -- Use ownerPos to "push" the clamped position to have a distance of segmentSize. This should give us a good
    -- -- approximation of where to put the segment on the ellipse.
    -- local targetPos = vec2.add(ownerPos, vec2.withAngle(vec2.angle(world.distance(clampedPos, ownerPos)),
    --   self.segmentSize))

    -- -- Approach that position
    -- approachPosition(targetPos)

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

    --world.debugText("direction: %s", util.toDirection(diff), mcontroller.position(), "green")
    world.debugLine(center, vec2.add(center, vec2.withAngle(currentAngle, self.segmentSize)), "blue")
    world.debugLine(center, vec2.add(center, vec2.withAngle(targetAngle, self.segmentSize)), "red")

    -- Set position to have a new angle from `center` (segmentSize distance away)
    mcontroller.setPosition(vec2.add(center, vec2.withAngle(newAngle, self.segmentSize)))
  end
end

-- ---Approaches the position `pos` at speed `ellipseClampSpeed` with control force `ellipseClampControlForce` for one
-- ---tick. Because the segment follow script locks the velocity to `{0, 0}` at all times, it is necessary to simulate
-- ---velocity and acceleration instead.
-- ---@param pos Vec2F the position to approach
-- function approachPosition(pos)
--   local dt = script.updateDt()

--   local targetVelocity = vec2.mul(vec2.norm(world.distance(pos, mcontroller.position())), ellipseClampSpeed)
--   currentEllipseClampVelocity = targetVelocity

--   mcontroller.setPosition(vec2.add(mcontroller.position(), vec2.mul(currentEllipseClampVelocity, dt)))
-- end

function notifyFinished(sourceId)
  local notification = {
    sourceId = entity.id(),
    type = "finished"
  }
  world.sendEntityMessage(sourceId, "notify", notification)
end