require "/scripts/util.lua"

local detectionRange
local hatchNotifyRange
local doNotKillMonsters

local nearbyMonsters
local consumedCount

local state

function init()
  detectionRange = config.getParameter("detectionRange")
  doNotKillMonsters = config.getParameter("doNotKillMonsters")
  hatchNotifyRange = 256

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

    if world.lineCollision(mcontroller.position(), world.nearestTo(mcontroller.position(), world.entityPosition(entityId))) then
      goto continue_query
    end

    if contains(doNotKillMonsters, world.monsterType(entityId)) then
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

  if #nearbyMonsters == 0 then
    state:set(states.hatch)
    return
  end

  local targetEntity = nearbyMonsters[math.random(1, #nearbyMonsters)]

  -- Stick tongue on entity.
  util.wait(2.5, function()
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

  if consumedCount >= 3 then
    state:set(states.hatch)
  else
    state:set(states.wait)
  end
end

function states.hatch()
  util.wait(2.0)

  animator.setAnimationState("body", "hatch")

  util.wait(2.0)

  -- for _ = 1, consumedCount do
  --   world.spawnMonster("v-morphum", mcontroller.position(), {aggressive = true})
  -- end
  if consumedCount < 1 then
    hatch("v-riftdevourer1")
  elseif consumedCount < 2 then
    hatch("v-riftdevourer2")
  else
    hatch("v-riftdevourer3")
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

function hatch(monsterType)
  local monsterId = world.spawnMonster(monsterType, mcontroller.position(), {
    aggressive = true,
    level = monster.level()
  })
  if monsterId then
    local queried = world.entityQuery(mcontroller.position(), hatchNotifyRange, {
      includedTypes = {"object"}
    })
    for _, entityId in ipairs(queried) do
      world.sendEntityMessage(entityId, "v-monsterwavespawner-monsterspawned", monsterId)
    end
  end
end

function clearTongue()
  monster.setAnimationParameter("chains", {})
end