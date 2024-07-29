require "/scripts/util.lua"
require "/scripts/rect.lua"
require "/scripts/voidedattackutil.lua"

local oldInit = init or function() end
local oldUpdate = update or function() end

local attacks
local laserLength

local ellipseClampDistance
local laserActivateDistance
local currentEllipseAngle
local distanceToClamped

local defaultFireVolume

local currentStateReset

local turretIsActive  -- If true, then the turret will not be rotated with the body.

function init()
  oldInit()

  attacks = {
    sides = states.sideProjectileGen("v-centipedepoisonshot2", "v-sideprojectilelaserpoison"),
    sides2 = states.sideProjectileGen("v-centipedeelectricshot2", "v-sideprojectilelaserelectric"),
    targeted = states.targetedProjectileGen("v-centipedepoisonshot"),
    targeted2 = states.targetedProjectileGen("v-centipedeelectricshot"),
    targeted3 = states.targetedProjectileGen("v-centipedeelectricshot", 1.0, {speed = 1, acceleration = 100}, 0.4),
    laserConstrict = states.laserConstrictGen("laserpoison", "laserPoison"),
    laserConstrict2 = states.laserConstrictGen("laserelectric", "laserElectric"),
    laserConstrictEnd = states.laserConstrictEndGen("laserpoison", "laserPoisonLoop"),
    laserConstrictEnd2 = states.laserConstrictEndGen("laserelectric", "laserElectricLoop"),
    mine = states.spawnMine
  }

  laserLength = 128

  ellipseClampDistance = 10

  laserActivateDistance = 3
  currentEllipseAngle = nil
  distanceToClamped = nil

  defaultFireVolume = 1.0

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

  -- If the turret is not active...
  if not turretIsActive then
    -- Rotate it with the body.
    animator.resetTransformationGroup("turret")
    animator.rotateTransformationGroup("turret", mcontroller.rotation())
  end

  state:update()
end

states = {}

function states.noop()
  while true do
    coroutine.yield()
  end
end

function states.sideProjectileGen(projectileType, laserProjectileType)
  return function(sourceId)
    local windupTime = 1.0

    local projectileOffset = {3.5, 0}  -- Adjusts to the aim vector of the projectile
    local projectileParameters = {power = v_scaledPower(10), speed = 1, acceleration = 50,
        damageRepeatGroup = "v-centipedeboss-sideprojectile"}
    local windupParameters = {timeToLive = windupTime}

    spawnLaser(laserProjectileType, {0, 1}, true, windupParameters)
    spawnLaser(laserProjectileType, {0, -1}, true, windupParameters)

    animator.setAnimationState("body", "windup")

    util.wait(windupTime)

    -- Calculate aim vectors and projectile positions
    local aimVector1 = vec2.rotate({0, 1}, mcontroller.rotation())
    local aimVector2 = vec2.rotate({0, -1}, mcontroller.rotation())
    local projectilePosition1 = vec2.add(mcontroller.position(), vec2.rotate(projectileOffset, vec2.angle(aimVector1)))
    local projectilePosition2 = vec2.add(mcontroller.position(), vec2.rotate(projectileOffset, vec2.angle(aimVector2)))

    -- Projectile on one side
    world.spawnProjectile(projectileType, projectilePosition1, entity.id(), aimVector1, false, projectileParameters)

    -- Projectile on the other side.
    world.spawnProjectile(projectileType, projectilePosition2, entity.id(), aimVector2, false, projectileParameters)

    animator.setAnimationState("body", "fire")
    animator.playSound("fireSides")

    notifyFinished(sourceId)

    state:set(states.noop)
  end
end

function states.targetedProjectileGen(projectileType, windupTime, projectileParameters, fireVolume)
  return function(sourceId, targetId)
    currentStateReset = function()
      animator.setAnimationState("targetlaser", "inactive")
      animator.setAnimationState("turret", "idle")
      turretIsActive = false
    end


    windupTime = windupTime or 1.0
    fireVolume = fireVolume or defaultFireVolume
    local winddownTime = 0.25

    local projectileOffset = {4, 0}  -- Adjusts to the aim vector of the projectile

    local params = copy(projectileParameters) or {}
    params.power = v_scaledPower(params.power or 15)

    animator.setAnimationState("turret", "windup")
    animator.setAnimationState("targetlaser", "active")

    turretIsActive = true

    -- Show laser while winding up
    util.wait(windupTime, function()
      animator.resetTransformationGroup("turret")
      animator.rotateTransformationGroup("turret", vec2.angle(entity.distanceToEntity(targetId)))
    end)

    -- Fire projectile at target
    entityDirection = vec2.norm(entity.distanceToEntity(targetId))

    world.spawnProjectile(
      projectileType,
      vec2.add(mcontroller.position(), vec2.rotate(projectileOffset, vec2.angle(entityDirection))),
      entity.id(),
      entityDirection,
      false,
      params
    )

    animator.setAnimationState("targetlaser", "inactive")
    animator.setAnimationState("turret", "fire")
    animator.setSoundVolume("fire", fireVolume)
    animator.playSound("fire")

    util.wait(winddownTime)

    turretIsActive = false

    notifyFinished(sourceId)

    state:set(states.noop)
  end
end

function states.laserConstrictGen(laserStateName, laserSoundPrefix)
  return function()
    -- Unset distanceToClamped
    distanceToClamped = nil

    local dt = script.updateDt()

    local updateEllipseLaser = function()
      -- Update laser to use currentEllipseAngle, if provided.
      if currentEllipseAngle then
        turretIsActive = true  -- Set turretIsActive to true (this is redundant, but it works!)
        animator.resetTransformationGroup("turret")
        animator.rotateTransformationGroup("turret", currentEllipseAngle)
      end
    end

    local windupTime = 3.0

    animator.setAnimationState("turret", "windup")
    animator.setAnimationState(laserStateName, "windup")
    -- animator.setAnimationState("targetlaser", "active")
    animator.playSound(laserSoundPrefix .. "Charge")

    local playedLoopSound = false

    -- Wait until distanceToClamped is given, disanceToClamped is less than laserActivateDistance, and windupTime seconds
    -- have passed.
    local timer = windupTime
    while not distanceToClamped or distanceToClamped >= laserActivateDistance or timer > 0 do
      updateEllipseLaser()

      -- If the timer has reached zero and the loop sound has not played yet...
      if timer <= 0 and not playedLoopSound then
        animator.playSound(laserSoundPrefix .. "ChargedLoop", -1)
        playedLoopSound = true
      end

      timer = timer - dt
      coroutine.yield()
    end

    animator.stopAllSounds(laserSoundPrefix .. "ChargedLoop")
    -- animator.setAnimationState("targetlaser", "inactive")
    animator.setAnimationState(laserStateName, "fire")

    animator.playSound("laserFire")
    animator.playSound(laserSoundPrefix .. "Loop", -1)

    -- Afterwards, update the laser forever. The laser stops when the laserEnd attack is triggered.
    while true do
      updateEllipseLaser()

      coroutine.yield()
    end
  end
end

function states.laserConstrictEndGen(laserStateName, laserLoopSound)
  return function(sourceId)
    local winddownTime = 0.5

    -- -- Just in case the laser never fires, the pointer is set to inactive.
    -- animator.setAnimationState("targetlaser", "inactive")

    animator.setAnimationState(laserStateName, "winddown")

    animator.stopAllSounds(laserLoopSound)
    animator.playSound("laserEnd")

    util.wait(winddownTime)

    animator.setAnimationState("turret", "idle")

    turretIsActive = false

    notifyFinished(sourceId)

    state:set(states.noop)
  end
end

function states.spawnMine(sourceId)
  local targetOffsetRegion = {-38, -42, 38, 42}

  local targetPosition = vec2.add(rect.randomPoint(targetOffsetRegion), getCenterPosition())

  local projectileType = "v-centipedeminetele"
  local projectileParameters = {
    power = v_scaledPower(15),
    targetPosition = targetPosition
  }
  local projectileOffset = {4, 0}  -- Adjusts to the firing direction of the projectile
  local windupTime = 0.5
  local winddownTime = 0.25

  animator.setAnimationState("turret", "windup")

  turretIsActive = true

  util.wait(windupTime, function()
    -- Rotate turret to target position
    animator.resetTransformationGroup("turret")
    animator.rotateTransformationGroup("turret", vec2.angle(world.distance(targetPosition, mcontroller.position())))
  end)

  -- Get projectile position.
  local aimVector = vec2.angle(world.distance(targetPosition, mcontroller.position()))
  local projectilePosition = vec2.add(mcontroller.position(), vec2.rotate(projectileOffset, aimVector))

  world.spawnProjectile(projectileType, projectilePosition, entity.id(), {1, 0}, false, projectileParameters)

  animator.setAnimationState("turret", "fire")
  animator.playSound("fireMine")

  util.wait(winddownTime)

  turretIsActive = false

  notifyFinished(sourceId)

  state:set(states.noop)
end

function spawnLaser(projectileType, direction, adjustToRotation, params)
  -- adjust the direction to the entity's current rotation is adjustToRotation is set to true. Don't otherwise.
  direction = adjustToRotation and vec2.rotate(direction, mcontroller.rotation()) or direction

  params.rotationCenter = mcontroller.position()

  -- Spawn the laser. It is offset by half of the laser length (adjusted to the direction)
  world.spawnProjectile(
    projectileType,
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
  animator.setAnimationState("turret", "idle")

  --animator.stopAllSounds("laserPoisonChargedLoop")
  animator.stopAllSounds("laserElectricChargedLoop")
  animator.stopAllSounds("laserPoisonLoop")
  animator.stopAllSounds("laserElectricLoop")

  animator.resetTransformationGroup("turret")

  turretIsActive = false

  state:set(states.noop)
end

function activatePhase2()
  animator.setGlobalTag("phase", "2")
end