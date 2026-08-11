--[[
  Attempts to spawn a rift zone
  Mechanics:
  * Must be minSpawnCooldown seconds since the last time it was spawned (or since this script was first initialized)
    * This condition is enforced by storing the universe time at which the Titan last spawned and checking the current
    time against it.
  * Player must be on a new planet for at least minPlanetStayTime seconds
    * This condition is enforced by storing the amount of time that the player has been on each planet type
  * The world type must be in a specific list (worldTypeWhitelist).
  * Player must be in a region with dungeon ID 65535.
    * Enforced by the Titan of Darkness checking if it is in a region with dungeon ID 65535 immediately after spawning.
  * There must not already be a Titan of Darkness
    * Enforced through the use of unique IDs.
  * Every spawnAttemptInterval seconds, attempts to spawn the Titan of Darkness. Has a spawning probability of
  spawnProbability
  * The rift zone is spawned anywhere on screen.

  The probability that the Titan of Darkness has spawned at least once after n seconds, assuming that all other
  conditions have been met, can be calculated using the formula P = 1 - (1 - spawnProbability) ^
  math.floor(n / spawnAttemptInterval).
]]

require "/scripts/util.lua"
require "/scripts/vec2.lua"

-- Parameters
local minSpawnCooldown  -- The amount of time to wait before spawning the rift zone again
local minPlanetStayTime  -- The player must have been on the current planet type for this amount of time
local worldTypeWhitelist  -- List of worlds on which the rift zone is allowed to spawn
local spawnAttemptInterval  -- How often the script should attempt to spawn the rift zone
local spawnProbability  -- The chance of the spawn succeeding
local numEventsPerOrbit  -- Number of events that can occur for each orbit

local spawnAttemptTimer  -- Amount of time elapsed since the last spawn attempt
local worldTypeStayTime  -- Amount of time that the player has spent on the current world so far

-- State variables
local scriptIsEnabled
local stagehandSpawned
local currentCoordinates
local prevRiftEventSegment

function init()
  local cfg = root.assetJson("/v-riftzones.config")
  scriptIsEnabled = true
  worldTypeWhitelist = cfg.allowedWorldTypes

  local worldType = world.type()
  -- If the current world type is not in the worldTypeWhitelist...
  if not contains(worldTypeWhitelist, worldType) then
    -- Abort and turn off all other functions
    script.setUpdateDelta(0)
    scriptIsEnabled = false
    return
  end

  -- minSpawnCooldown = 0
  minSpawnCooldown = cfg.spawnCooldown
  minPlanetStayTime = cfg.minPlanetStayTime
  spawnAttemptInterval = cfg.noCoordsModeParameters.spawnAttemptInterval
  spawnProbability = cfg.noCoordsModeParameters.spawnProbability

  referenceRiftZoneCount = cfg.referenceRiftZoneCount
  referenceWorldSize = cfg.referenceWorldSize
  numEventsPerOrbit = cfg.coordsModeParameters.numEventsPerOrbit

  spawnAttemptTimer = 0

  if not storage.lastRiftZoneSpawnTime then
    storage.lastRiftZoneSpawnTime = world.time()
  end

  if not storage.worldTypeStayTimes then
    storage.worldTypeStayTimes = {}
  end

  -- Define stay time for the current world type if it is not defined already.
  if not storage.worldTypeStayTimes[worldType] then
    storage.worldTypeStayTimes[worldType] = 0
  end

  -- Cache world type stay time for current world.
  worldTypeStayTime = storage.worldTypeStayTimes[worldType]

  -- Store current celestial coordinates for easy access.
  currentCoordinates = getCelestialCoordinates()
  prevRiftEventSegment = world.getProperty("v-riftZone-prevOrbitAngle")

  message.setHandler("v-riftzonespawn-actLikeIStayedLongEnough", function(_, _, worldType)
    actLikeIStayedLongEnough(worldType)
  end)

  message.setHandler("v-riftzonespawn-planetStayTime", function()
    return worldTypeStayTime
  end)

  script.setUpdateDelta(60)
end

function update(dt)
  if not currentCoordinates then
    currentCoordinates = getCelestialCoordinates()
    return
  end

  -- Spawn stagehand.
  if not stagehandSpawned then
    world.spawnStagehand(mcontroller.position(), "v-riftzonemanager", {
      worldCoordinates = currentCoordinates
    })
    stagehandSpawned = true
    return
  end

  -- if worldTypeStayTime > minPlanetStayTime then
  --   if currentCoordinates then
  --     coordsMode()
  --   else
  --     noCoordsMode(dt)
  --   end
  -- end

  worldTypeStayTime = worldTypeStayTime + dt
end

function uninit()
  if scriptIsEnabled then
    -- Save world type stay time
    storage.worldTypeStayTimes[world.type()] = worldTypeStayTime
    world.setProperty("v-riftZone-prevOrbitAngle", prevRiftEventSegment)
  end
end

---Returns celestial coordinates for the current world, if it is a celestial world. Returns `nil` otherwise.
---@return CelestialCoordinate?
function getCelestialCoordinates()
  local worldId = player.worldId()
  local first, last, x, y, z, planet = worldId:find("CelestialWorld:(%-?%d+):(%-?%d+):(%-?%d+):(%-?%d+)")
  if first then  -- Check if the string pattern matching succeeded.
    local satellite = worldId:match(":(%-?%d+)", last)  -- tonumber returns nil if satellite is nil.
    return {
      location = {tonumber(x), tonumber(y), tonumber(z)},
      planet = tonumber(planet),
      satellite = tonumber(satellite)
    }
  end
end

-- Call this function repeatedly in update if coordinates are found.
function coordsMode()
  local position = celestial.planetPosition(currentCoordinates)
  local angle = vec2.angle(position)

  local riftEventSegment = math.floor(angle * numEventsPerOrbit / (2 * math.pi))

  world.debugText("angle: %s, segment: %s", angle, riftEventSegment, mcontroller.position(), "green")

  -- Crossed a fissure; spawn rifts
  if prevRiftEventSegment and prevRiftEventSegment ~= riftEventSegment
  and world.time() > storage.lastRiftZoneSpawnTime + minSpawnCooldown then
    spawnRiftZones()
    storage.lastRiftZoneSpawnTime = world.time()  -- Update lastRiftZoneSpawnTime variable.
  end

  prevRiftEventSegment = riftEventSegment
end

-- Call this function repeatedly in update if no coordinates are found.
function noCoordsMode(dt)
  world.debugText("timer: %s", spawnAttemptTimer, mcontroller.position(), "green")

  spawnAttemptTimer = spawnAttemptTimer + dt
  -- Every spawnAttemptInterval seconds...
  if spawnAttemptTimer > spawnAttemptInterval then
    -- With a probability of spawnProbability...
    if math.random() <= spawnProbability
    and world.time() > storage.lastRiftZoneSpawnTime + minSpawnCooldown then  -- If the rift zone spawning cooldown has ended...
      spawnRiftZones()
      storage.lastRiftZoneSpawnTime = world.time()  -- Update lastRiftZoneSpawnTime variable.
    end

    spawnAttemptTimer = 0  -- Reset timer
  end
end

function spawnRiftZones()
  world.sendEntityMessage("v-riftzonemanager-stagehand", "beginEvent")
end

function actLikeIStayedLongEnough(worldType)
  if worldType == world.type() then
    worldTypeStayTime = minPlanetStayTime
  end
  storage.worldTypeStayTimes[worldType] = minPlanetStayTime
end