require "/scripts/util.lua"
require "/scripts/vec2.lua"
require "/scripts/v-behavior.lua"
require "/scripts/v-movement.lua"

local task
local cfg
local args

local state

local shouldDieVar

function init()
  task = config.getParameter("task")
  cfg = config.getParameter("taskConfig")
  args = config.getParameter("taskArguments")

  monster.setDamageBar("None")

  state = FSM:new()

  shouldDieVar = false

  script.setUpdateDelta(1)

  state:set(states.grab)
end

function update(dt)
  state:update()
end

function shouldDie()
  return shouldDieVar
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

    util.wait(grabDelay)

    -- Get target position
    local targetPos = world.entityPosition(args.target)
    -- Get distance to target
    local targetDistance = world.distance(targetPos, startPos)
    -- Get grab end position
    local grabEndPosition = vec2.add(startPos, vec2.mul(vec2.norm(targetDistance), vec2.mag(targetDistance) + grabEndDistance))

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