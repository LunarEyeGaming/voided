require "/scripts/util.lua"

local detectionRange

local nearbyMonsters
local consumedCount

local state

function init()
  detectionRange = config.getParameter("detectionRange")

  nearbyMonsters = {}
  consumedCount = 0

  state = FSM:new()
  state:set(states.wait)

  status.addEphemeralEffect("invulnerable", 2 ^ 32)
end

function update(dt)
  local ownDamageTeam = entity.damageTeam()

  local queried = world.entityQuery(mcontroller.position(), detectionRange, {includedTypes = {"monster"}, withoutEntityId = entity.id()})
  nearbyMonsters = {}
  for _, entityId in ipairs(queried) do
    local damageTeam = world.entityDamageTeam(entityId)
    if not hasSameMaster(entityId) then
      goto continue_query
    end

    if damageTeam.type ~= ownDamageTeam.type then
      goto continue_query
    end

    table.insert(nearbyMonsters, entityId)

    ::continue_query::
  end

  state:update(dt)
end

states = {}

function states.wait()
  coroutine.yield()

  util.wait(3.0, function()
    if #nearbyMonsters == 0 then
      state:set(states.hatch)
    end
  end)

  state:set(states.consume)
end

function states.consume()
  animator.setAnimationState("body", "consumewindup")

  util.wait(1.0)

  animator.setAnimationState("body", "consume")

  local targetEntity = nearbyMonsters[math.random(1, #nearbyMonsters)]

  -- Stick tongue on entity.
  util.wait(1.5, function()
    world.debugText("Consuming", mcontroller.position(), "green")
    if not world.entityExists(targetEntity) then
      clearTongue()
      state:set(states.wait)
    else
      drawTongue(mcontroller.position(), world.entityPosition(targetEntity))
    end
  end)

  clearTongue()

  -- Consume.
  if world.entityExists(targetEntity) then
    world.callScriptedEntity(targetEntity, "monster.setDropPool", nil)
    world.callScriptedEntity(targetEntity, "status.applySelfDamageRequest", {
      damage = 1000,
      damageSourceKind = "v-void",
      damageType = "IgnoresDef"
    })
    consumedCount = consumedCount + 1
  end

  state:set(states.wait)
end

function states.hatch()
  util.wait(2.0)

  animator.setAnimationState("body", "hatch")

  util.wait(2.0)

  -- for _ = 1, consumedCount do
  --   world.spawnMonster("v-morphum", mcontroller.position(), {aggressive = true})
  -- end
  if consumedCount < 2 then
    world.spawnMonster("v-riftdevourer1", mcontroller.position(), {
      aggressive = true,
      level = monster.level()
    })
  elseif consumedCount < 4 then
    world.spawnMonster("v-riftdevourer2", mcontroller.position(), {
      aggressive = true,
      level = monster.level()
    })
  else
    world.spawnMonster("v-riftdevourer3", mcontroller.position(), {
      aggressive = true,
      level = monster.level()
    })
  end
end

---Returns `true` if the current entity has the same master as the given `entityId`, `false` otherwise--i.e., both this
---entity and `entityId` are clientsided or serversided.
function hasSameMaster(entityId)
  return (entity.id() < 0 and entityId < 0) or (entity.id() > 0 and entityId > 0)
end

function drawTongue(posStart, posEnd)
  local tongue = config.getParameter("tongue")

  tongue.startPosition = posStart
  tongue.endPosition = posEnd

  monster.setAnimationParameter("chains", {tongue})
end

function clearTongue()
  monster.setAnimationParameter("chains", {})
end