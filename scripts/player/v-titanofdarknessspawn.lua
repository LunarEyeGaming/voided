--[[
  Attempts to spawn the Titan of Darkness.
  Mechanics:
  * Must be minSpawnCooldown seconds since the last time it was spawned (or since this script was first initialized)
    * This condition is enforced by storing the universe time at which the Titan last spawned and checking the current
    time against it.
  * Player must be on a new planet for at least minPlanetStayTime seconds
    * This condition is enforced by storing the amount of time that the player has been on each planet type
  * The world type must be in a specific list (worldTypeWhitelist).
  * Player must have a tier 9 or above weapon or set of armor (will be added later). Maybe at least one tier 9 piece of
  equipment?
  * Player must be in a region with dungeon ID 65535.
    * Enforced by the Titan of Darkness checking if it is in a region with dungeon ID 65535 immediately after spawning.
  * There must not already be a Titan of Darkness
    * Enforced through the use of unique IDs.
  * Every spawnAttemptInterval seconds, attempts to spawn the Titan of Darkness. Has a spawning probability of
  spawnProbability
  * The Titan of Darkness is spawned on top of the player (at which point, the AI should give the player time to react),
  with a threat level of 10.

  The probability that the Titan of Darkness has spawned at least once after n seconds, assuming that all other
  conditions have been met, can be calculated using the formula P = 1 - (1 - spawnProbability) ^
  math.floor(n / spawnAttemptInterval).
]]

require "/scripts/util.lua"

local allowedEquipmentLevels  -- The player must possess at least one item with a "level" value in `allowedEquipmentLevels`.
local minSpawnCooldown  -- The amount of time to wait before spawning the Titan of Darkness again
local minPlanetStayTime  -- The player must have been on the current planet type for this amount of time
local worldTypeWhitelist  -- List of worlds on which the Titan of Darkness is allowed to spawn
local spawnAttemptInterval  -- How often the script should attempt to spawn the Titan
local spawnProbability  -- The chance of the spawn succeeding
local titanMonsterType  -- The monster type of the Titan of Darkness
local titanUniqueId  -- The unique ID of the Titan of Darkness
local titanLevel  -- The level of the Titan of Darkness to use

local spawnAttemptTimer  -- Amount of time elapsed since the last spawn attempt
local worldTypeStayTime  -- Amount of time that the player has spent on the current world so far
local attemptedSpawnPromise  -- A promise representing a pending Titan spawn. Used to confirm that a Titan has spawned.

local scriptIsEnabled

function init()
  scriptIsEnabled = true
  worldTypeWhitelist = {"v-voltage", "v-toxicwasteland"}

  local worldType = world.type()
  -- If the current world type is not in the worldTypeWhitelist...
  if not contains(worldTypeWhitelist, worldType) then
    -- Abort and turn off all other functions
    script.setUpdateDelta(0)
    scriptIsEnabled = false
    return
  end

  allowedEquipmentLevels = {9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20}
  minSpawnCooldown = 60 * 30
  minPlanetStayTime = 60 * 30
  spawnAttemptInterval = 30
  spawnProbability = 0.05
  titanMonsterType = "v-titanofdarkness"
  titanUniqueId = "v-titanofdarkness"
  titanLevel = 10

  spawnAttemptTimer = 0

  if not storage.lastTitanSpawnTime then
    storage.lastTitanSpawnTime = world.time()
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
  spawnAttemptTimer = spawnAttemptTimer + dt
  -- Every spawnAttemptInterval seconds...
  if spawnAttemptTimer > spawnAttemptInterval then
    -- With a probability of spawnProbability...
    if math.random() <= spawnProbability
    and world.time() > storage.lastTitanSpawnTime + minSpawnCooldown  -- If the Titan spawning cooldown has ended...
    and worldTypeStayTime > minPlanetStayTime  -- The player has stayed for longer than minPlanetStayTime...
    and hasStrongEnoughEquipment() then  -- And the player has strong enough equipment...
      world.spawnMonster(titanMonsterType, mcontroller.position(), {level = titanLevel})
      attemptedSpawnPromise = world.findUniqueEntity(titanUniqueId)
    end

    spawnAttemptTimer = 0  -- Reset timer
  end

  -- If a spawn was attempted and it has finished...
  if attemptedSpawnPromise and attemptedSpawnPromise:finished() then
    -- If it was successful...
    if attemptedSpawnPromise:succeeded() then
      -- Update the last spawned time.
      storage.lastTitanSpawnTime = world.time()
    end
    attemptedSpawnPromise = nil  -- Clear attemptedSpawnPromise
  end

  worldTypeStayTime = worldTypeStayTime + dt
end

---Returns whether or not the player has at least one item with a `level` value that is inside `allowedEquipmentLevels`.
---@return boolean
function hasStrongEnoughEquipment()
  for _, level in ipairs(allowedEquipmentLevels) do
    if player.hasItemWithParameter("level", level) then
      return true
    end
  end

  return false
end

function uninit()
  if scriptIsEnabled then
    -- Save world type stay time
    storage.worldTypeStayTimes[world.type()] = worldTypeStayTime
  end
end