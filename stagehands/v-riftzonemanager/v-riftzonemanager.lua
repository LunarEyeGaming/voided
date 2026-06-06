require "/scripts/vec2.lua"
require "/scripts/rect.lua"

local SMALL_RECT = {-1, -1, 1, 1}

local defaultRiftZoneVelocity

local postInitCalled


function init()
  defaultRiftZoneVelocity = {-5, 0}

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
      world.debugPoint(zoomedOutPos, "magenta")
    end

    -- Update position
    riftZone.position = vec2.add(riftZone.position, vec2.mul(riftZone.velocity or defaultRiftZoneVelocity, dt))

    -- Spawn if possible
    if world.regionActive(rect.translate(SMALL_RECT, riftZone.position)) then
      table.insert(riftZonesToSpawn, riftZone)
      table.remove(riftZones, i)
    -- Clean up data
    elseif world.time() > riftZone.stateData.deathTime then
      table.remove(riftZones, i)
    end
  end

  world.setProperty("v-riftZones", riftZones)

  for _, riftZone in ipairs(riftZonesToSpawn) do
    world.spawnMonster("v-riftzone", riftZone.position, {
      velocity = riftZone.velocity or defaultRiftZoneVelocity,
      stateData = riftZone.stateData
    })
  end
end