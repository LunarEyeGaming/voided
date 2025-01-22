require "/scripts/util.lua"
require "/scripts/vec2.lua"
require "/scripts/v-behavior.lua"
require "/scripts/v-movement.lua"
require "/scripts/actions/v-attackutil.lua"
require "/scripts/actions/boss/v-titanofdarkness.lua"

local appearSpecs

local task
local cfg
local args

local anchorPoint

local forearmLength
local rearArmLength
local wristOffset
local handRotationRate  -- Rotation rate for the hand.

local minArmSpan
local maxArmSpan

local state

local shouldDieVar

local rotateHandSmoothly  -- Whether or not the hand should rotate smoothly to handTargetAngle or jump to it instantly.
local useAppearAnimation  -- Whether or not to use the appear animation automatically.
local currentHandAngle  -- Current rotation of the hand
local handTargetAngle  -- Current rotation that the hand is going toward
local maxHandAngle  -- The maximum allowable difference between currentHandAngle and the current forearm angle.

function init()
  monster.setAnimationParameter("riftTrails", config.getParameter("riftTrails"))
  monster.setAnimationParameter("riftTrailDuration", config.getParameter("riftTrailDuration"))
  monster.setAnimationParameter("riftTrailThicknessVariance", config.getParameter("riftTrailThicknessVariance"))

  appearSpecs = config.getParameter("appearSpecs")

  task = config.getParameter("task")
  cfg = config.getParameter("taskConfig")[task] or {}
  args = config.getParameter("taskArguments")

  anchorPoint = config.getParameter("anchorPoint")

  forearmLength = animator.partProperty("forearm", "length")
  rearArmLength = animator.partProperty("reararm", "length")
  wristOffset = animator.partProperty("forearm", "wristPoint")
  handRotationRate = animator.partProperty("hand", "rotationRate") * math.pi / 180
  maxHandAngle = animator.partProperty("hand", "maxHandAngle") * math.pi / 180

  -- Invariant derived values.
  minArmSpan = math.abs(rearArmLength - forearmLength)
  maxArmSpan = rearArmLength + forearmLength

  monster.setDamageBar("None")

  state = FSM:new()

  shouldDieVar = false

  if cfg.rotateHandSmoothly ~= nil then
    rotateHandSmoothly = cfg.rotateHandSmoothly
  else
    rotateHandSmoothly = true
  end

  if cfg.useAppearAnimation ~= nil then
    useAppearAnimation = cfg.useAppearAnimation
  else
    useAppearAnimation = true
  end

  -- Use more sensible values for currentHandAngle and handTargetAngle by getting the values from updateArm()
  local forearmAngle, _ = updateArm()
  currentHandAngle = forearmAngle + math.pi
  handTargetAngle = forearmAngle + math.pi
  setHandRotation(currentHandAngle)  -- Also update the angle because updateHandAngle won't perform updates unless currentHandAngle ~= handTargetAngle.

  script.setUpdateDelta(1)

  if useAppearAnimation then
    state:set(appear)
  else
    state:set(tasks[task])
  end
end

function update(dt)
  state:update()

  -- world.debugPoint(anchorPoint, "green")
  updateArm()
  updateHandAngle(dt)
end

function shouldDie()
  return shouldDieVar
end

---Updates placement of arm segments. Returns the forearm angle and rear arm angle.
---@return number
---@return number
function updateArm()
  local anchorPointDistance = world.distance(anchorPoint, mcontroller.position())
  local baseAngle = vec2.angle(anchorPointDistance)
  local armSpan = vec2.mag(anchorPointDistance)
  -- Calculating armName angles fails if armSpan < minArmSpan or armSpan > maxArmSpan, so move the anchorPoint to be
  -- within this range and update armSpan accordingly.
  if armSpan < minArmSpan then
    anchorPoint = vec2.add(mcontroller.position(), vec2.mul(anchorPointDistance, minArmSpan / armSpan))
    armSpan = minArmSpan
  elseif armSpan > maxArmSpan then
    anchorPoint = vec2.add(mcontroller.position(), vec2.mul(anchorPointDistance, maxArmSpan / armSpan))
    armSpan = maxArmSpan
  end
  -- Calculate arm angles.
  local forearmAngle = math.acos((forearmLength ^ 2 + armSpan ^ 2 - rearArmLength ^ 2) / (2 * forearmLength * armSpan))
  -- Subtract math.pi from the initial result to get clockwise rotation from pointing outward instead of
  -- counterclockwise rotation from pointing inward
  local rearArmAngle = math.acos((forearmLength ^ 2 + rearArmLength ^ 2 - armSpan ^ 2) / (2 * forearmLength * rearArmLength)) - math.pi

  local correctedForearmAngle

  -- If currentHandAngle is defined...
  if currentHandAngle then
    -- If the absolute forearm angle (rotated pi radians) deviates more than maxHandAngle radians from the current hand
    -- direction...
    local revForearmToHandAngle = util.angleDiff(baseAngle + forearmAngle - math.pi, currentHandAngle)
    if math.abs(revForearmToHandAngle) > maxHandAngle then
      -- Calculate correction amount (angle diff between absolute revForearmToHandAngle and maxHandAngle), then multiply
      -- by the direction of revForearmToHandAngle.
      local correctionAmount = (math.abs(revForearmToHandAngle) - maxHandAngle) * util.toDirection(revForearmToHandAngle)
      correctedForearmAngle = baseAngle + forearmAngle + correctionAmount
      -- Rotate anchor point.
      anchorPoint = vec2.add(mcontroller.position(), vec2.rotate(anchorPointDistance, correctionAmount))
    else
      correctedForearmAngle = baseAngle + forearmAngle
    end
  else
    correctedForearmAngle = baseAngle + forearmAngle
  end

  animator.resetTransformationGroup("wristjoint")
  animator.resetTransformationGroup("elbowjoint")
  animator.rotateTransformationGroup("wristjoint", correctedForearmAngle, wristOffset)
  animator.rotateTransformationGroup("elbowjoint", rearArmAngle, animator.partProperty("reararm", "elbowPoint"))

  -- Set flipping
  local wrappedForearmAngle = util.wrapAngle(correctedForearmAngle)
  if math.pi / 2 < wrappedForearmAngle and wrappedForearmAngle < 3 * math.pi / 2 then
    animator.setAnimationState("forearm", "flipped")
  else
    animator.setAnimationState("forearm", "normal")
  end

  local wrappedRearArmAngle = util.wrapAngle(rearArmAngle + correctedForearmAngle)
  if math.pi / 2 < wrappedRearArmAngle and wrappedRearArmAngle < 3 * math.pi / 2 then
    animator.setAnimationState("reararm", "flipped")
  else
    animator.setAnimationState("reararm", "normal")
  end


  return baseAngle + forearmAngle, rearArmAngle
end

-- Coroutine function. Makes the arm appear and do the configured task.
function appear()
  animator.setAnimationState("hand", cfg.initialState or "fist")

  v_titanAppear(appearSpecs)

  state:set(tasks[task])
end

-- Nudges the hand angle toward the `handTargetAngle`, or jumps to it if `rotateHandSmoothly` is `false`.
function updateHandAngle(dt)
  -- Nudge hand angle if `rotateHandSmoothly` is `true`. Otherwise, jump to `handTargetAngle`.
  if rotateHandSmoothly then
    local angleDiff = util.angleDiff(currentHandAngle, handTargetAngle)

    -- If the difference is not zero (to avoid throwing off attempts to lock to the target angle)...
    if angleDiff ~= 0 then
      -- Calculate angle nudge amount, add to `currentHandAngle`, and save the result.
      local newHandAngle
      if angleDiff < 0 then
        newHandAngle = currentHandAngle - handRotationRate * dt
      else
        newHandAngle = currentHandAngle + handRotationRate * dt
      end

      -- If the new difference changed sign...
      if util.angleDiff(newHandAngle, handTargetAngle) * angleDiff < 0 then
        -- Lock the current hand angle to the target angle
        currentHandAngle = handTargetAngle
      else
        -- Otherwise, set it to the saved value.
        currentHandAngle = newHandAngle
      end

      -- Update hand rotation
      setHandRotation(currentHandAngle)
    end
  else
    currentHandAngle = handTargetAngle
    setHandRotation(currentHandAngle)
  end
end

-- Sets the hand rotation directly, applying flipping if necessary.
function setHandRotation(angle)
  -- Wrap the angle.
  angle = util.wrapAngle(angle)

  animator.resetTransformationGroup("hand")
  animator.resetTransformationGroup("facing")
  local adjustedAngle
  local direction
  if math.pi / 2 < angle and angle < 3 * math.pi / 2 then
    adjustedAngle = math.pi - angle
    direction = -1
  else
    adjustedAngle = angle
    direction = 1
  end
  animator.rotateTransformationGroup("hand", adjustedAngle)
  animator.scaleTransformationGroup("facing", {direction, 1})
end

tasks = {}

function tasks.grab()
  local rq = vBehavior.requireArgsGen("tasks.grab", args)

  if rq{"target"} then
    local startPos = mcontroller.position()
    local grabbedEntities = {}

    -- Get target position
    local targetPos = world.entityPosition(args.target)
    -- Get distance to target
    local targetDistance = world.distance(targetPos, startPos)
    -- Get grab end position
    local grabEndPosition = vec2.add(startPos, vec2.mul(vec2.norm(targetDistance), vec2.mag(targetDistance) + cfg.grabEndDistance))

    handTargetAngle = vec2.angle(targetDistance)

    animator.setAnimationState("hand", "openhand")

    util.wait(cfg.grabDelay)

    local threads = {
      coroutine.create(function()
        vMovementA.flyToPosition(grabEndPosition, cfg.extendSpeed, cfg.extendForce, cfg.tolerance)
        vMovementA.stop(cfg.stopForce)
      end),
      coroutine.create(function()
        -- Keep on adding grabbed entities forever. This function will inevitably be interrupted.
        while true do
          local queried = world.entityQuery(mcontroller.position(), cfg.grabRange, {includedTypes = {"player"}})

          for _, entityId in ipairs(queried) do
            world.sendEntityMessage(entityId, "applyStatusEffect", "v-grabbed")
            world.sendEntityMessage(entityId, "v-grabbed-sourceEntity", entity.id())
          end

          -- Copy queried over to grabbedEntities
          table.move(queried, 1, #queried, 1, grabbedEntities)

          coroutine.yield()
        end
      end)
    }

    -- Run threads until one of them is finished
    while util.parallel(table.unpack(threads)) do
      coroutine.yield()
    end

    animator.setAnimationState("hand", "fist")

    -- Fly back to starting position.
    vMovementA.flyToPosition(startPos, cfg.retractSpeed, cfg.retractForce, cfg.tolerance)
    vMovementA.stop(cfg.stopForce)

    -- For each grabbed entity...
    for _, entityId in ipairs(grabbedEntities) do
      -- Make the grabbed effect expire if the entity exists.
      if world.entityExists(entityId) then
        world.sendEntityMessage(entityId, "v-grabbed-expire")
      end
    end
  end

  finish()
end

function tasks.burrowingRift()
  local rq = vBehavior.requireArgsGen("tasks.burrowingRift", args)

  local projectileConfig = cfg.projectileConfig or {}
  projectileConfig.power = vAttack.scaledPower(projectileConfig.power or 10)
  local pointOffsetAngle = -cfg.pointOffsetAngle * math.pi / 180

  local maxNumPrevPos = 3  -- Maximum length of prevPosList

  if rq{"target"} then
    animator.setAnimationState("hand", "dig")

    -- Get point angle (completely random)
    local pointAngle = math.random() * 2 * math.pi

    -- Set position and direction. The position is offset to be opposite to the point angle. Also save current position
    -- for future reference
    local spawnPos = mcontroller.position()
    mcontroller.setPosition(vec2.add(mcontroller.position(), vec2.withAngle(pointAngle - math.pi, cfg.pointDistance)))
    handTargetAngle = pointAngle

    v_titanAppear(appearSpecs)

    -- Calculate aim vector.
    local aimVector = vec2.withAngle(pointAngle - pointOffsetAngle)
    -- Spawn the projectile with the calculated aim vector.
    local projectileId = world.spawnProjectile(cfg.projectileType, spawnPos, config.getParameter("master"),
    aimVector, false, projectileConfig)

    local prevPosList  -- List of previous projectile positions, including current projectile positions. Used to estimate projectile velocity

    -- Check if the projectile exists. If so, initialize the prevPosList to have `maxNumPrevPos` copies of the
    -- projectile's position. Also set the rift trail animation script to track this entity.
    if world.entityExists(projectileId) then
      monster.setAnimationParameter("riftTrailTrackingEntity", projectileId)
      local pos = world.entityPosition(projectileId)
      prevPosList = {}
      for _ = 1, maxNumPrevPos do
        table.insert(prevPosList, pos)
      end
    end

    -- While the projectile exists...
    while world.entityExists(projectileId) do
      -- Push a new entry. The oldest (first) entry is removed beforehand.
      table.remove(prevPosList, 1)
      table.insert(prevPosList, world.entityPosition(projectileId))
      -- Calculate projectile velocity by getting the difference of the latest and earliest entries.
      local projVelocity = world.distance(prevPosList[1], prevPosList[#prevPosList])

      -- If the velocity is not zero (either component has to be a nonzero value)...
      if projVelocity[1] ~= 0 or projVelocity[2] ~= 0 then
        local pointVector = vec2.mul(vec2.norm(vec2.rotate(projVelocity, pointOffsetAngle)), cfg.pointDistance)
        -- Offset hand in opposite direction of that at which the hand is pointing.
        mcontroller.setPosition(vec2.add(world.entityPosition(projectileId), pointVector))
        handTargetAngle = vec2.angle(pointVector) + math.pi
      end


      -- Make the projectile go towards the target.
      world.sendEntityMessage(projectileId, "setTargetPosition", world.entityPosition(args.target))

      coroutine.yield()
    end

    monster.setAnimationParameter("riftTrailTrackingEntity", nil)

    util.wait(cfg.emergeWaitTime)
  end

  finish()
end

function tasks.punch()
  local rq = vBehavior.requireArgsGen("tasks.punch", args)

  if rq{"target"} then
    local punchDelay = 1.0
    local punchEndDistance = 10  -- The number of additional blocks to travel beyond the player when punching.
    local extendSpeed = 75
    local extendForce = 800
    local retractSpeed = 50
    local retractForce = 200
    local stopForce = 200
    local tolerance = 10

    local startPos = mcontroller.position()

    local predictedTargetDistance

    animator.setAnimationState("hand", "fist")

    util.wait(punchDelay, function()
      -- Get target position
      local targetPos = world.entityPosition(args.target)
      -- Get magnitude to target
      local targetMagnitude = world.magnitude(targetPos, startPos)
      -- Predict target's movements. The last expression estimates the arrival time of the punch.
      local targetAngle = anglePrediction(mcontroller.position(), args.target, targetMagnitude / extendSpeed)
      -- Get predicted target distance.
      predictedTargetDistance = vec2.withAngle(targetAngle, targetMagnitude)

      handTargetAngle = vec2.angle(predictedTargetDistance)
    end)

    -- Get punch end position. To avoid weirdness, we derive the direction from currentHandAngle instead of
    -- predictedTargetDistance. Also, lock the handTargetAngle to currentHandAngle.
    local punchEndPosition = vec2.add(startPos, vec2.withAngle(currentHandAngle, vec2.mag(predictedTargetDistance) + punchEndDistance))
    handTargetAngle = currentHandAngle

    animator.playSound("punch")

    monster.setDamageOnTouch(true)

    vMovementA.flyToPosition(punchEndPosition, extendSpeed, extendForce, tolerance)
    vMovementA.stop(stopForce)

    monster.setDamageOnTouch(false)

    -- Fly back to starting position.
    vMovementA.flyToPosition(startPos, retractSpeed, retractForce, tolerance)
    vMovementA.stop(stopForce)
  end

  finish()
end

function tasks.bomb()
  local rq = vBehavior.requireArgsGen("tasks.bomb", args)

  if rq{"target"} then
    animator.setAnimationState("hand", cfg.initialState or "fist")

    local threads = {
      coroutine.create(function()
        v_titanAppear(appearSpecs)
      end),
      coroutine.create(function()
        while true do
          if world.entityExists(args.target) then
            local targetPos = world.entityPosition(args.target)
            local toTarget = vec2.norm(world.distance(targetPos, mcontroller.position()))
            handTargetAngle = vec2.angle(toTarget)  -- Update hand target angle
            mcontroller.setPosition(vec2.add(targetPos, vec2.mul(toTarget, -cfg.followDistance)))
          end

          coroutine.yield()
        end
      end)
    }

    while util.parallel(table.unpack(threads)) do
      coroutine.yield()
    end

    local projectileParameters = copy(cfg.projectileParameters or {})
    projectileParameters.power = vAttack.scaledPower(projectileParameters.power or 10)

    util.wait(cfg.releaseDelay, function()
      if world.entityExists(args.target) then
        local targetPos = world.entityPosition(args.target)
        local toTarget = vec2.norm(world.distance(targetPos, mcontroller.position()))
        handTargetAngle = vec2.angle(toTarget)  -- Update hand target angle
        mcontroller.setPosition(vec2.add(targetPos, vec2.mul(toTarget, -cfg.followDistance)))
      end
    end)

    if world.entityExists(args.target) then
      local toTarget = vec2.norm(world.distance(world.entityPosition(args.target), mcontroller.position()))
      local projectilePos = vec2.add(mcontroller.position(), vec2.mul(toTarget, cfg.followDistance))
      world.spawnProjectile(cfg.projectileType, projectilePos, entity.id(), {0, 0}, false, projectileParameters)

      animator.setAnimationState("hand", "openhand")
    end

    finish()
  end
end

function tasks.test()
  local target = world.players()[1]
  while true do
    local targetAngle = vec2.angle(world.distance(world.entityPosition(target), mcontroller.position()))

    handTargetAngle = targetAngle

    coroutine.yield()
  end
end

function tasks.test2()
  local target = world.players()[1]
  while true do
    mcontroller.setPosition(world.entityPosition(target))

    coroutine.yield()
  end
end

---Notifies the master that the arm is finished and dies.
function finish()
  -- Disappear
  v_titanAppear{
    appearTime = appearSpecs.appearTime,
    visionStartRotationRate = appearSpecs.visionEndRotationRate,
    visionEndRotationRate = appearSpecs.visionStartRotationRate,
    visionStartRadius = appearSpecs.visionEndRadius,
    visionEndRadius = appearSpecs.visionStartRadius,
    startAlpha = 255,
    endAlpha = 0
  }
  -- Die
  world.sendEntityMessage(config.getParameter("master"), "notify", {type = "v-titanofdarkness-armFinished"})
  shouldDieVar = true
  coroutine.yield()
end