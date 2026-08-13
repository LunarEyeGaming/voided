require "/scripts/util.lua"
require "/scripts/vec2.lua"
require "/scripts/rect.lua"

require "/scripts/v-vec2.lua"
require "/scripts/v-time.lua"
require "/scripts/v-world.lua"

local SMALL_RECT = {-1, -1, 1, 1}

local worldCoordinates
local defaultRiftZoneVelocity
local playerProximityRegion
local lightningOffsetRegion
local lightningStrikeProbability
local relocationProbability
local invisibleOre
local defaultTimeToLive

local maxSpawnDelay  -- Maximum time to wait before spawning a rift zone
local minSpawnDelay  -- Minimum time to wait before spawning a rift zone
local maxTriggerInterval
local minTriggerInterval
local densityTriggerThreshold  -- Maximum rift zone density at which a rift zone event can trigger
local riftZoneDensity
local riftZoneSpacing
local weatherTypes  -- The potential weather events that could occur in a rift zone.
local minPlanetStayTime

local nextTriggerTime

local activeRiftZones
local allRiftZones
local rng
local postInitCalled
local thread

function init()
  worldCoordinates = config.getParameter("worldCoordinates")
  local cfg = root.assetJson("/v-riftzones.config")
  defaultRiftZoneVelocity = cfg.defaultZoneVelocity
  local lightningTriggerRange = cfg.lightningTriggerRange
  playerProximityRegion = {-lightningTriggerRange, -lightningTriggerRange, lightningTriggerRange, lightningTriggerRange}
  lightningOffsetRegion = cfg.lightningOffsetRegion
  lightningStrikeProbability = cfg.lightningStrikeProbability
  relocationProbability = cfg.relocationProbability
  invisibleOre = cfg.invisibleOre
  defaultTimeToLive = cfg.defaultTimeToLive

  riftZoneDensity = cfg.riftZoneSpawnDensity
  riftZoneSpacing = cfg.riftZoneSpawnSpacing

  maxSpawnDelay = cfg.spawnDelayRange[2]
  minSpawnDelay = cfg.spawnDelayRange[1]

  maxTriggerInterval = cfg.triggerIntervalRange[2]
  minTriggerInterval = cfg.triggerIntervalRange[1]
  densityTriggerThreshold = cfg.densityTriggerThreshold

  weatherTypes = {"meteors", "gravispheres", "destabilization"}

  minPlanetStayTime = cfg.minPlanetStayTime

  vTime.addInterval(1, cleanUpAfterRiftZones)
  vTime.addInterval(1, attemptRiftZoneSpawn)

  message.setHandler("cleanUp", function(_, _, blocksToClearFG, blocksToClearBG, oresToClearFG, oresToClearBG, riftZoneData)
    local partitionedBlocksFG = partitionByChunk(blocksToClearFG)
    local partitionedBlocksBG = partitionByChunk(blocksToClearBG)
    local partitionedOresFG = partitionByChunk(oresToClearFG)
    local partitionedOresBG = partitionByChunk(oresToClearBG)

    pushPartitionToStorageProperty("blocksToRemoveFG", partitionedBlocksFG)
    pushPartitionToStorageProperty("blocksToRemoveBG", partitionedBlocksBG)
    pushPartitionToStorageProperty("oresToRemoveFG", partitionedOresFG)
    pushPartitionToStorageProperty("oresToRemoveBG", partitionedOresBG)

    local riftZones = world.getProperty("v-riftZones") or jarray()
    table.insert(riftZones, riftZoneData)
    world.setProperty("v-riftZones", riftZones)
  end)

  message.setHandler("getAllRiftZones", function()
    return allRiftZones
  end)

  allRiftZones = {}
  activeRiftZones = {}
  rng = sb.makeRandomSource(world.time() % maxTriggerInterval + worldCoordinates.location[1] + worldCoordinates.location[2] + worldCoordinates.location[3])

  nextTriggerTime = world.getProperty("v-riftZoneTriggerTime")
  if not nextTriggerTime then
    nextTriggerTime = world.time() + rng:randf(minTriggerInterval, maxTriggerInterval)
    world.setProperty("v-riftZoneTriggerTime", nextTriggerTime)
  end

  if not storage.cleanupInfo then
    storage.cleanupInfo = {
      blocksToRemoveFG = {},
      blocksToRemoveBG = {},
      oresToRemoveFG = {},
      oresToRemoveBG = {}
    }
  end

  postInitCalled = false
end

function postInit()
  local stagehandId = world.loadUniqueEntity("v-riftzonemanager-stagehand")

  -- Set unique ID if no stagehand with that unique ID exists. Otherwise (if it is not the stagehand with the unique
  -- ID), die.
  if stagehandId == 0 then
    stagehand.setUniqueId("v-riftzonemanager-stagehand")
  elseif stagehandId ~= entity.id() then
    stagehand.die()
  end
end

function update(dt)
  if not postInitCalled then
    postInit()
    postInitCalled = true
    return
  end

  vTime.update(dt)

  sb.setLogMap("v-riftzone_nextTriggerTime", "%s", nextTriggerTime - world.time())

  updateThread()

  local riftZones = world.getProperty("v-riftZones") or jarray()
  updateRiftZoneSpawnPoints(riftZones)

  updateRiftZones(riftZones, dt)

  strikeRiftZoneLightning(riftZones)
end

function updateThread()
  if thread then
    if coroutine.status(thread) == "dead" then
      thread = nil
    else
      local status, result = coroutine.resume(thread)
      if not status then
        error(result)
      end
    end
  end
end

function updateRiftZones(riftZones, dt)
  local riftZonesToSpawn = {}

  local zoomOut = function(anchor, pos, factor)
    local posRelative = world.distance(pos, anchor)
    return vec2.add(vec2.mul(posRelative, 1 / factor), anchor)
  end
  local playerPos = world.entityPosition(world.players()[1] or 0)

  for i = #riftZones, 1, -1 do
    local riftZone = riftZones[i]

    if playerPos then
      local zoomedOutPos = zoomOut(playerPos, riftZone.position, 120)
      world.debugText("%s", riftZone.stateData.deathTime - world.time(), zoomedOutPos, "magenta")
    end

    -- Update position
    riftZone.position = vec2.add(riftZone.position, vec2.mul(riftZone.velocity or defaultRiftZoneVelocity, dt))

    -- Spawn if possible
    if canSpawn(riftZone.position) then
      table.insert(riftZonesToSpawn, riftZone)
      table.remove(riftZones, i)
    -- Kill / relocate rift zones
    elseif world.time() > riftZone.stateData.deathTime then
      table.remove(riftZones, i)
      if math.random() < relocationProbability then
        createRiftZone(riftZones, riftZone)
      end
    end
  end

  world.setProperty("v-riftZones", riftZones)

  for _, riftZone in ipairs(riftZonesToSpawn) do
    local entityId = world.spawnMonster("v-riftzone", riftZone.position, {
      velocity = riftZone.velocity or defaultRiftZoneVelocity,
      stateData = riftZone.stateData,
      level = riftZone.level,
      timeToLive = riftZone.timeToLive
    })
    if entityId then
      table.insert(activeRiftZones, {entityId = entityId, timeToLive = riftZone.timeToLive})
    end
  end

  activeRiftZones = util.filter(activeRiftZones, function(x) return world.entityExists(x.entityId) end)

  for _, riftZone in ipairs(activeRiftZones) do
    -- Update time to live.
    local timeToLive = world.callScriptedEntity(riftZone.entityId, "v_timeToLive")
    riftZone.timeToLive = timeToLive

    if playerPos then
      local zoomedOutPos = zoomOut(playerPos, world.entityPosition(riftZone.entityId), 120)
      world.debugText("%s", timeToLive, zoomedOutPos, "magenta")
    end
  end

  allRiftZones = {}

  for _, riftZone in ipairs(riftZones) do
    table.insert(allRiftZones, {position = riftZone.position, timeToLiveRatio = riftZone.timeToLive / defaultTimeToLive})
  end

  for _, riftZone in ipairs(activeRiftZones) do
    table.insert(allRiftZones, {position = world.entityPosition(riftZone.entityId), timeToLiveRatio = riftZone.timeToLive / defaultTimeToLive})
  end
end

function strikeRiftZoneLightning(riftZones)
  local players = world.players()
  for _, playerId in ipairs(players) do
    local playerPos = world.entityPosition(playerId)

    if playerPos and closeToARiftZone(playerPos, riftZones) then
      if math.random() < lightningStrikeProbability then
        local pos = vec2.add(rect.randomPoint(lightningOffsetRegion), playerPos)
        world.spawnMonster("v-riftzonelightning", pos)
      end
    end
  end
end

function updateRiftZoneSpawnPoints(riftZones)
  local riftZoneSpawnPoints = world.getProperty("v-riftZoneSpawnPoints") or jarray()

  for i = #riftZoneSpawnPoints, 1, -1 do
    local point = riftZoneSpawnPoints[i]
    if world.time() > point.spawnTime then
      table.insert(riftZones, {
        position = point.position,
        velocity = defaultRiftZoneVelocity,
        stateData = {deathTime = world.time() + defaultTimeToLive},
        level = world.threatLevel(),
        timeToLive = defaultTimeToLive
      })
      table.remove(riftZoneSpawnPoints, i)
    end
  end

  world.setProperty("v-riftZoneSpawnPoints", riftZoneSpawnPoints)
end

function createRiftZone(riftZones, oldRiftZone)
  local size = world.size()
  local pos = {math.random() * size[1], math.random() * size[2]}
  local deathTime = world.time() + oldRiftZone.timeToLive
  table.insert(riftZones, {
    position = pos,
    velocity = oldRiftZone.velocity,
    stateData = {deathTime = deathTime},
    level = oldRiftZone.level,
    timeToLive = oldRiftZone.timeToLive
  })
end

function countRiftZones()
  local queried = world.entityQuery(stagehand.position(), 6000, {
    includedTypes = {"monster"}
  })

  local count = 0
  for _, entityId in ipairs(queried) do
    if world.monsterType(entityId) == "v-riftzone" then
      count = count + 1
    end
  end

  sb.setLogMap("v-riftzone-count", "%s", count)
end

function beginEvent()
  local riftZoneSpawnPoints = world.getProperty("v-riftZoneSpawnPoints") or jarray()
  local size = world.size()

  -- Build a list of spawn points from which to select.
  local spawnPoints = {}
  for x = 0, size[1], riftZoneSpacing do
    for y = 0, size[2], riftZoneSpacing do
      table.insert(spawnPoints, {x, y})
    end
  end

  shuffle(spawnPoints)

  -- Select density * #spawnPoints points and insert them into riftZoneSpawnPoints, each with a randomized spawn time.
  for i = 1, math.floor(#spawnPoints * riftZoneDensity) do
    local timeToLive = math.random() * (maxSpawnDelay - minSpawnDelay) + minSpawnDelay
    local spawnTime = world.time() + timeToLive
    table.insert(riftZoneSpawnPoints, {spawnTime = spawnTime, position = spawnPoints[i]})
  end
  world.setProperty("v-riftZoneSpawnPoints", riftZoneSpawnPoints)

  world.spawnMonster("v-riftzonecutscene", stagehand.position(), {masterId = world.players()[1]})

  -- Set weather
  world.setProperty("v-riftZoneWeather", weatherTypes[math.random(1, #weatherTypes)])
end

function canSpawn(position)
  return world.regionActive(rect.translate(SMALL_RECT, position))
end

function closeToARiftZone(position, riftZones)
  for _, riftZone in ipairs(riftZones) do
    local region = rect.translate(playerProximityRegion, riftZone.position)
    if region[1] <= position[1] and position[1] <= region[3]
      and region[2] <= position[2] and position[2] <= region[4] then
      return true
    end
  end

  return false
end

---Partitions blocks by chunks.
---@param blocks Vec2F[]
---@return table<string, Vec2F[]>
function partitionByChunk(blocks)
  local partition = {}

  for _, block in ipairs(blocks) do
    local sector = {block[1] // vWorld.SECTOR_SIZE, block[2] // vWorld.SECTOR_SIZE}

    local sectorStr = vVec2.iToString(sector)
    if not partition[sectorStr] then
      partition[sectorStr] = jarray()
    end

    table.insert(partition[sectorStr], block)
  end

  return partition
end

function pushPartitionToStorageProperty(propertyName, partition)
  local prop = storage.cleanupInfo[propertyName]
  for sectorStr, blocks in pairs(partition) do
    local propBlocks = prop[sectorStr]
    if not propBlocks then
      propBlocks = jarray()
      prop[sectorStr] = propBlocks
    end
    -- Append contents of blocks to propBlocks
    for _, block in ipairs(blocks) do
      table.insert(propBlocks, block)
    end
  end
end

function cleanUpAfterRiftZones()
  clearBlocks("blocksToRemoveFG", "foreground")
  clearBlocks("blocksToRemoveBG", "background")
  clearOres("oresToRemoveFG", "foreground")
  clearOres("oresToRemoveBG", "background")
end

function clearBlocks(propertyName, layer)
  local blocksToClear = storage.cleanupInfo[propertyName]

  for sectorStr, blocks in pairs(blocksToClear) do
    local sector = vVec2.iFromString(sectorStr)
    local sectorRect = {
      sector[1] * vWorld.SECTOR_SIZE,
      sector[2] * vWorld.SECTOR_SIZE,
      sector[1] * vWorld.SECTOR_SIZE + vWorld.SECTOR_SIZE - 1,
      sector[2] * vWorld.SECTOR_SIZE + vWorld.SECTOR_SIZE - 1
    }
    if world.regionActive(sectorRect) then
      world.damageTiles(blocks, layer, blocks[1], "blockish", 2 ^ 32, 0)

      blocksToClear[sectorStr] = nil
    end
  end
end

function clearOres(propertyName, layer)
  local oresToClear = storage.cleanupInfo[propertyName]

  for sectorStr, ores in pairs(oresToClear) do
    local sector = vVec2.iFromString(sectorStr)
    local sectorRect = {
      sector[1] * vWorld.SECTOR_SIZE,
      sector[2] * vWorld.SECTOR_SIZE,
      sector[1] * vWorld.SECTOR_SIZE + vWorld.SECTOR_SIZE - 1,
      sector[2] * vWorld.SECTOR_SIZE + vWorld.SECTOR_SIZE - 1
    }
    if world.regionActive(sectorRect) then
      for _, ore in ipairs(ores) do
        world.placeMod(ore, layer, invisibleOre)
      end

      oresToClear[sectorStr] = nil
    end
  end
end

function attemptRiftZoneSpawn()
  if world.time() > nextTriggerTime
  and not titanOfDarknessActive()
  and currentDensity() <= densityTriggerThreshold then
    thread = coroutine.create(riftZoneSpawnCo)
  end
end

function titanOfDarknessActive()
  return world.loadUniqueEntity("v-titanofdarkness") ~= 0
end

function currentDensity()
  -- Returns approximate density of rift zones (number of rift zones per riftZoneSpacing-sized cell). Does not include
  -- active rift zones.
  local riftZones = world.getProperty("v-riftZones") or jarray()

  local riftZoneCount = #riftZones

  local size = world.size()
  local maxNumRiftZones = (size[1] // riftZoneSpacing) * (size[2] // riftZoneSpacing)

  local density = riftZoneCount / maxNumRiftZones

  return density
end

function riftZoneSpawnCo()
  -- Broadcast a message requesting planet stay time among all players. At least one must have stayed on the planet for minPlanetStayTime seconds.
  local playerStayedLongEnough
  vWorldA.sendEntityMessageToTargets(function(promise)
    local res = promise:result()
    if res and res >= minPlanetStayTime then
      playerStayedLongEnough = true
    end
  end, function(promise)
    sb.logError("v-riftzonemanager: Promise failed: %s", promise:error())
  end, world.players(), "v-riftzonespawn-planetStayTime")

  if playerStayedLongEnough then
    beginEvent()
    nextTriggerTime = world.time() + rng:randf(minTriggerInterval, maxTriggerInterval)
    world.setProperty("v-riftZoneTriggerTime", nextTriggerTime)
  end
end