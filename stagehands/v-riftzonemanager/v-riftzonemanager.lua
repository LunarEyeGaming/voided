require "/scripts/vec2.lua"
require "/scripts/rect.lua"

local SMALL_RECT = {-1, -1, 1, 1}

local defaultRiftZoneVelocity
local playerProximityRegion
local lightningOffsetRegion
local riftZoneDuration

local postInitCalled


function init()
  defaultRiftZoneVelocity = {-5, 0}
  playerProximityRegion = {-300, -300, 300, 300}
  lightningOffsetRegion = {-100, -100, 100, 100}
  riftZoneDuration = 600

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

  local riftZones = world.getProperty("v-riftZones") or jarray()
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
      if math.random() < 0.90 then
        createRiftZone(riftZones, riftZone)
      end
    end

    -- countRiftZones()
  end

  local players = world.players()
  for _, playerId in ipairs(players) do
    local playerPos = world.entityPosition(playerId)

    if playerPos and closeToARiftZone(playerPos, riftZones) then
      if math.random() < 0.1 then
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

function canSpawn(position)
  return
  world.regionActive(rect.translate(SMALL_RECT, position))
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