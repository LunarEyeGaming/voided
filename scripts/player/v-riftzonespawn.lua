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

local minSpawnCooldown  -- The amount of time to wait before spawning the rift zone again
local minPlanetStayTime  -- The player must have been on the current planet type for this amount of time
local worldTypeWhitelist  -- List of worlds on which the rift zone is allowed to spawn
local spawnAttemptInterval  -- How often the script should attempt to spawn the rift zone
local spawnProbability  -- The chance of the spawn succeeding
local riftZoneCount  -- The number of rift zones to spawn in each attempt

local spawnAttemptTimer  -- Amount of time elapsed since the last spawn attempt
local worldTypeStayTime  -- Amount of time that the player has spent on the current world so far

local scriptIsEnabled
local stagehandSpawned

function init()
  scriptIsEnabled = true
  worldTypeWhitelist = {"v-voltage", "v-toxicwasteland", "v-ministar", "v-entropic"}

  local worldType = world.type()
  -- If the current world type is not in the worldTypeWhitelist...
  if not contains(worldTypeWhitelist, worldType) then
    -- Abort and turn off all other functions
    script.setUpdateDelta(0)
    scriptIsEnabled = false
    return
  end

  minSpawnCooldown = 60 * 60
  minPlanetStayTime = 60 * 30
  spawnAttemptInterval = 30
  spawnProbability = 1.0

  riftZoneCount = 100

  spawnAttemptTimer = 0

  if storage.firstEncounter == nil then
    storage.firstEncounter = true
  end

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

  script.setUpdateDelta(60)
end

function update(dt)
  -- Spawn stagehand after fetching celestial parameters.
  if not stagehandSpawned then
    world.spawnStagehand(mcontroller.position(), "v-riftzonemanager")
    stagehandSpawned = true
    return
  end
  spawnAttemptTimer = spawnAttemptTimer + dt
  -- Every spawnAttemptInterval seconds...
  if spawnAttemptTimer > spawnAttemptInterval then
    -- With a probability of spawnProbability...
    if math.random() <= spawnProbability
    and world.time() > storage.lastRiftZoneSpawnTime + minSpawnCooldown  -- If the rift zone spawning cooldown has ended...
    and worldTypeStayTime > minPlanetStayTime then  -- And the player has stayed for longer than minPlanetStayTime...
      local riftZones = world.getProperty("v-riftZones") or jarray()
      local deathTime = world.time() + 1200
      for _ = 1, riftZoneCount do
        local size = world.size()
        local pos = {math.random() * size[1], math.random() * size[2]}
        table.insert(riftZones, {position = pos, velocity = {-5, 0}, stateData = {deathTime = deathTime}})
      end
      world.setProperty("v-riftZones", riftZones)
      storage.lastRiftZoneSpawnTime = world.time()  -- Update lastRiftZoneSpawnTime variable.
    end

    spawnAttemptTimer = 0  -- Reset timer
  end

  worldTypeStayTime = worldTypeStayTime + dt
end

function uninit()
  if scriptIsEnabled then
    -- Save world type stay time
    storage.worldTypeStayTimes[world.type()] = worldTypeStayTime
  end
end