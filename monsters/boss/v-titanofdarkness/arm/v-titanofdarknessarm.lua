require "/scripts/util.lua"
require "/scripts/vec2.lua"
require "/scripts/v-behavior.lua"
require "/scripts/v-movement.lua"
require "/scripts/actions/v-attackutil.lua"
require "/scripts/actions/boss/v-titanofdarkness.lua"

local task
local cfg
local args

local anchorPoint

local forearmLength
local rearArmLength

local wristOffset

local minArmSpan
local maxArmSpan

local state

local shouldDieVar

function init()
  task = config.getParameter("task")
  cfg = config.getParameter("taskConfig")
  args = config.getParameter("taskArguments")

  anchorPoint = config.getParameter("anchorPoint")

  forearmLength = animator.partProperty("forearm", "length")
  rearArmLength = animator.partProperty("reararm", "length")

  wristOffset = animator.partProperty("forearm", "wristPoint")

  -- Invariant derived values.
  minArmSpan = math.abs(rearArmLength - forearmLength)
  maxArmSpan = rearArmLength + forearmLength

  monster.setDamageBar("None")

  state = FSM:new()

  shouldDieVar = false

  script.setUpdateDelta(1)

  state:set(appear)
end

function update(dt)
  state:update()

  world.debugPoint(anchorPoint, "green")
  updateArm()
end

function shouldDie()
  return shouldDieVar
end

---Updates placement of arm segments.
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

  animator.resetTransformationGroup("wristjoint")
  animator.resetTransformationGroup("elbowjoint")
  animator.rotateTransformationGroup("wristjoint", baseAngle + forearmAngle, wristOffset)
  animator.rotateTransformationGroup("elbowjoint", rearArmAngle, animator.partProperty("reararm", "elbowPoint"))
end

-- Coroutine function.
function appear()
  v_titanAppear{
    appearTime = 0.5,
    visionStartRotationRate = 0,
    visionEndRotationRate = 0.25,
    visionStartRadius = 10,
    visionEndRadius = 1
  }

  state:set(tasks[task])
end

tasks = {}

function tasks.grab()
  local rq = vBehavior.requireArgsGen("tasks.grab", args)

  if rq{"target"} then
    local grabDelay = 2.5
    local grabRadius = 5
    local grabEndDistance = 10  -- The number of additional blocks to travel beyond the player when grabbing.
    local extendSpeed = 75
    local extendForce = 800
    local retractSpeed = 50
    local retractForce = 200
    local stopForce = 200
    local tolerance = 10

    local startPos = mcontroller.position()
    local grabbedEntities = {}

    -- Get target position
    local targetPos = world.entityPosition(args.target)
    -- Get distance to target
    local targetDistance = world.distance(targetPos, startPos)
    -- Get grab end position
    local grabEndPosition = vec2.add(startPos, vec2.mul(vec2.norm(targetDistance), vec2.mag(targetDistance) + grabEndDistance))

    animator.resetTransformationGroup("hand")
    animator.rotateTransformationGroup("hand", vec2.angle(targetDistance))

    util.wait(grabDelay)

    local threads = {
      coroutine.create(function()
        vMovementA.flyToPosition(grabEndPosition, extendSpeed, extendForce, tolerance)
        vMovementA.stop(stopForce)
      end),
      coroutine.create(function()
        -- Keep on adding grabbed entities forever. This function will inevitably be interrupted.
        while true do
          local queried = world.entityQuery(mcontroller.position(), grabRadius, {includedTypes = {"player"}})

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

    -- Fly back to starting position.
    vMovementA.flyToPosition(startPos, retractSpeed, retractForce, tolerance)
    vMovementA.stop(stopForce)

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

  local emergeWaitTime = 0.0
  local pointDistance = 5
  local maxNumPrevPos = 3  -- Maximum length of prevPosList
  local pointOffsetAngle = -math.pi / 2

  local projectileType = "v-titanburrowingrift"
  local projectileConfig = {}
  projectileConfig.power = vAttack.scaledPower(projectileConfig.power or 10)

  if rq{"target"} then
    -- Spawn the projectile with a completely random aim vector.
    local projectileId = world.spawnProjectile(projectileType, mcontroller.position(), config.getParameter("master"),
    vec2.withAngle(math.random() * 2 * math.pi), false, projectileConfig)

    local prevPosList  -- List of previous projectile positions, including current projectile positions. Used to estimate projectile velocity

    -- Check if the projectile exists. If so, initialize the prevPosList to have `maxNumPrevPos` copies of the
    -- projectile's position.
    if world.entityExists(projectileId) then
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
      local pointVector = vec2.mul(vec2.norm(vec2.rotate(projVelocity, pointOffsetAngle)), pointDistance)
      -- Offset hand in opposite direction of that at which the hand is pointing.
      mcontroller.setPosition(vec2.add(world.entityPosition(projectileId), pointVector))
      -- mcontroller.setPosition(world.entityPosition(projectileId))

      animator.resetTransformationGroup("hand")
      animator.rotateTransformationGroup("hand", vec2.angle(pointVector) + math.pi)

      -- Make the projectile go towards the target.
      world.sendEntityMessage(projectileId, "setTargetPosition", world.entityPosition(args.target))

      coroutine.yield()
    end

    util.wait(emergeWaitTime)
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

    util.wait(punchDelay, function()
      -- Get target position
      local targetPos = world.entityPosition(args.target)
      -- Get magnitude to target
      local targetMagnitude = world.magnitude(targetPos, startPos)
      -- Predict target's movements. The last expression estimates the arrival time of the punch.
      local targetAngle = anglePrediction(mcontroller.position(), args.target, targetMagnitude / extendSpeed)
      -- Get predicted target distance.
      predictedTargetDistance = vec2.withAngle(targetAngle, targetMagnitude)

      animator.resetTransformationGroup("hand")
      animator.rotateTransformationGroup("hand", vec2.angle(predictedTargetDistance))
    end)

    -- Get punch end position
    local punchEndPosition = vec2.add(startPos, vec2.mul(vec2.norm(predictedTargetDistance), vec2.mag(predictedTargetDistance) + punchEndDistance))

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

---Notifies the master that the arm is finished and dies.
function finish()
  -- Disappear
  v_titanAppear{
    appearTime = 0.5,
    visionStartRotationRate = 0.25,
    visionEndRotationRate = 0,
    visionStartRadius = 1,
    visionEndRadius = 10,
    startAlpha = 255,
    endAlpha = 0
  }
  -- Die
  world.sendEntityMessage(config.getParameter("master"), "notify", {type = "v-titanofdarkness-armFinished"})
  shouldDieVar = true
  coroutine.yield()
end