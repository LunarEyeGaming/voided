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

  monster.setDamageBar("None")

  state = FSM:new()

  shouldDieVar = false

  script.setUpdateDelta(1)

  state:set(states.grab)
end

function update(dt)
  state:update()

  updateArm()
end

function shouldDie()
  return shouldDieVar
end

---Updates placement of arm segments.
function updateArm()
  local baseAngle = vec2.angle(world.distance(mcontroller.position(), anchorPoint))
  local armSpan = world.magnitude(mcontroller.position(), anchorPoint)
  -- Calculate arm angles
  local forearmAngle = math.acos((forearmLength ^ 2 + armSpan ^ 2 - rearArmLength ^ 2) / (2 * forearmLength * armSpan))
  -- Subtract math.pi from the initial result to get clockwise rotation from pointing outward instead of
  -- counterclockwise rotation from pointing inward
  local rearArmAngle = math.acos((forearmLength ^ 2 + rearArmLength ^ 2 - armSpan ^ 2) / (2 * forearmLength * rearArmLength)) - math.pi

  animator.resetTransformationGroup("wristjoint")
  animator.resetTransformationGroup("elbowjoint")
  animator.rotateTransformationGroup("wristjoint", baseAngle + forearmAngle, wristOffset)
  animator.rotateTransformationGroup("elbowjoint", rearArmAngle, animator.partProperty("reararm", "elbowPoint"))
end

states = {}

function states.grab()
  local rq = vBehavior.requireArgsGen("states.grab", args)

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