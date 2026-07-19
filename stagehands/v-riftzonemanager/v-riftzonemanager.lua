require "/scripts/util.lua"
require "/scripts/vec2.lua"
require "/scripts/rect.lua"

require "/scripts/v-vec2.lua"
require "/scripts/v-time.lua"
require "/scripts/v-world.lua"

local SMALL_RECT = {-1, -1, 1, 1}

local defaultRiftZoneVelocity
local playerProximityRegion
local lightningOffsetRegion
local lightningStrikeProbability
local relocationProbability
local invisibleOre
local defaultTimeToLive

local maxSpawnDelay  -- Maximum time to wait before spawning a rift zone
local minSpawnDelay  -- Minimum time to wait before spawning a rift zone
local riftZoneDensity
local riftZoneSpacing
local weatherTypes  -- The potential weather events that could occur in a rift zone.

local postInitCalled

function init()
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

  maxSpawnDelay = cfg.spawnDelayRange[1]
  minSpawnDelay = cfg.spawnDelayRange[2]

  weatherTypes = {"meteors", "gravispheres", "destabilization"}

  message.setHandler("beginEvent", function()
    beginEvent()
  end)

  vTime.addInterval(1, cleanUpAfterRiftZones)

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

  local riftZones = world.getProperty("v-riftZones") or jarray()
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
      -- world.debugPoint(zoomedOutPos, "magenta")
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

    -- countRiftZones()
  end

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

  world.setProperty("v-riftZones", riftZones)

  for _, riftZone in ipairs(riftZonesToSpawn) do
    world.spawnMonster("v-riftzone", riftZone.position, {
      velocity = riftZone.velocity or defaultRiftZoneVelocity,
      stateData = riftZone.stateData,
      level = riftZone.level,
      timeToLive = riftZone.timeToLive
    })
  end

  sb.setLogMap("v-riftzonemanager-spawnedRiftZones", "%s", #riftZonesToSpawn)
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

function cleanUpAfterRiftZones()
  clearBlocks("v-riftzone-blocksToRemoveFG", "foreground")
  clearBlocks("v-riftzone-blocksToRemoveBG", "background")
  clearOres("v-riftzone-oresToRemoveFG", "foreground")
  clearOres("v-riftzone-oresToRemoveBG", "background")
end

function clearBlocks(propertyName, layer)
  local blocksToClear = world.getProperty(propertyName) or {}

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

  world.setProperty(propertyName, blocksToClear)
end

function clearOres(propertyName, layer)
  local oresToClear = world.getProperty(propertyName) or {}

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

  world.setProperty(propertyName, oresToClear)
end