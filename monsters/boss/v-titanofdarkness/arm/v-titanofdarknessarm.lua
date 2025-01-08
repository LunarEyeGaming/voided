require "/scripts/util.lua"
require "/scripts/vec2.lua"
require "/scripts/v-behavior.lua"
require "/scripts/v-movement.lua"

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

  state:set(tasks[task])
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

tasks = {}

function tasks.grab()
  local rq = vBehavior.requireArgsGen("tasks.grab", args)

  if rq{"target"} then
    local grabDelay = 3.0
    local grabRadius = 5
    local grabEndDistance = 10  -- The number of additional blocks to travel beyond the player when grabbing.
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
        vMovementA.flyToPosition(grabEndPosition, 75, 800, 10)
        vMovementA.stop(200)
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
    vMovementA.flyToPosition(startPos, 50, 200, 10)
    vMovementA.stop(200)

    -- For each grabbed entity...
    for _, entityId in ipairs(grabbedEntities) do
      -- Make the grabbed effect expire if the entity exists.
      if world.entityExists(entityId) then
        world.sendEntityMessage(entityId, "v-grabbed-expire")
      end
    end
  end

  -- Die
  world.sendEntityMessage(config.getParameter("master"), "notify", {type = "v-titanofdarkness-armFinished"})
  shouldDieVar = true
  coroutine.yield()
end

function tasks.burrowingRift()
  local rq = vBehavior.requireArgsGen("tasks.burrowingRift", args)

  local emergeWaitTime = 0.5
  local pointDistance = 5

  if rq{"projectileId"} then
    while world.entityExists(args.projectileId) do
      -- local projVelocity = world.entityVelocity(args.projectileId)
      -- local pointVector = vec2.mul(vec2.norm(vec2.rotate(projVelocity, -math.pi / 2)), pointDistance)
      -- Offset hand in opposite direction of that at which the hand is pointing.
      mcontroller.setPosition(world.entityPosition(args.projectileId))

      -- animator.resetTransformationGroup("hand")
      -- animator.rotateTransformationGroup("hand", vec2.angle(pointVector) + math.pi)

      coroutine.yield()
    end

    util.wait(emergeWaitTime)
  end

  -- Die
  world.sendEntityMessage(config.getParameter("master"), "notify", {type = "v-titanofdarkness-armFinished"})
  shouldDieVar = true
  coroutine.yield()
end