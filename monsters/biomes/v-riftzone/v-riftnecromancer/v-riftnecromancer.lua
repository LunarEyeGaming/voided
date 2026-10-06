require "/scripts/util.lua"

-- Parameters
local doNotResurrectMonsters
local detectionRange
local minKills

-- State variables
local trackedMonsterTypes
local trackedMonsterParameters
local trackedMonsterPositions
local livingMonsters
local deadMonsters
local respawnedMonsters
local kills
local state

function init()
  doNotResurrectMonsters = config.getParameter("doNotResurrectMonsters")
  minKills = config.getParameter("minKills")
  detectionRange = config.getParameter("detectionRange")

  kills = 0
  trackedMonsterTypes = {}
  trackedMonsterParameters = {}
  trackedMonsterPositions = {}
  livingMonsters = {}
  deadMonsters = {}
  respawnedMonsters = {}

  state = FSM:new()

  state:set(states.wait)
end

function update(dt)
  state:update(dt)

  if kills < minKills then
    status.addEphemeralEffect("v-ancientshield")
  end

  local ownDamageTeam = entity.damageTeam()

  local queried = world.entityQuery(mcontroller.position(), detectionRange, {includedTypes = {"monster"}, withoutEntityId = entity.id()})

  -- Record information about newly detected monsters
  for _, entityId in ipairs(queried) do
    local monsterType = world.monsterType(entityId)
    local damageTeam = world.entityDamageTeam(entityId)

    if contains(doNotResurrectMonsters, monsterType) then
      goto continue_query
    end

    if not hasSameMaster(entityId) then
      goto continue_query
    end

    if damageTeam.type ~= ownDamageTeam.type then
      goto continue_query
    end

    if contains(livingMonsters, entityId) then
      goto continue_query
    end

    trackedMonsterTypes[entityId] = monsterType
    trackedMonsterParameters[entityId] = world.callScriptedEntity(entityId, "monster.uniqueParameters")
    local monsterLevel = world.callScriptedEntity(entityId, "monster.level")
    trackedMonsterParameters[entityId].level = math.max(monsterLevel, monster.level())

    table.insert(livingMonsters, entityId)

    ::continue_query::
  end

  -- Track the status of living monsters
  for i = #livingMonsters, 1, -1 do
    local entityId = livingMonsters[i]

    if not world.entityExists(entityId) then
      table.remove(livingMonsters, i)
      table.insert(deadMonsters, entityId)
    else
      trackedMonsterPositions[entityId] = world.entityPosition(entityId)
    end
  end

  -- Track the status of respawned monsters.
  for i = #respawnedMonsters, 1, -1 do
    local entityId = respawnedMonsters[i]
    if not world.entityExists(entityId) then
      table.remove(respawnedMonsters, i)
      kills = kills + 1
    end
  end

  -- Debug
  for _, entityId in ipairs(livingMonsters) do
    world.debugPoint(trackedMonsterPositions[entityId], "green")
  end

  for _, entityId in ipairs(deadMonsters) do
    world.debugText("%s", trackedMonsterTypes[entityId], trackedMonsterPositions[entityId], "red")
  end
end

function die()
  for _, entityId in ipairs(respawnedMonsters) do
    world.sendEntityMessage(entityId, "despawn")
  end
end

states = {}

function states.resurrect()
  animator.setAnimationState("body", "windup")
  util.wait(1.0)

  -- Resurrect dead monsters
  for _, entityId in ipairs(deadMonsters) do
    -- Don't drop anything.
    trackedMonsterParameters[entityId].dropPools = {"empty"}

    local newEntityId = world.spawnMonster(trackedMonsterTypes[entityId], trackedMonsterPositions[entityId], trackedMonsterParameters[entityId])
    if not newEntityId then
      sb.logError("Failed to spawn monster. Type: %s, position: %s, parameters: %s", trackedMonsterTypes[entityId], trackedMonsterPositions[entityId], trackedMonsterParameters[entityId])
    else
      world.callScriptedEntity(newEntityId, "status.addEphemeralEffect", "v-resurrected", 2 ^ 32)
      table.insert(respawnedMonsters, newEntityId)
    end
  end

  deadMonsters = {}

  animator.setAnimationState("body", "fire")

  state:set(states.cooldown)
end

function states.cooldown()
  util.wait(10)

  state:set(states.wait)
end

function states.wait()
  -- Wait for a dead monster
  while #deadMonsters == 0 do
    coroutine.yield()
  end

  state:set(states.resurrect)
end

---Returns `true` if the current entity has the same master as the given `entityId`, `false` otherwise--i.e., both this
---entity and `entityId` are clientsided or serversided.
function hasSameMaster(entityId)
  return (entity.id() < 0 and entityId < 0) or (entity.id() > 0 and entityId > 0)
end