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
    * Enforced by checking all blocks that the player occupies.
  * There must not already be a Titan of Darkness
  * Every spawnAttemptInterval seconds, attempts to spawn the Titan of Darkness. Has a spawning probability of
  spawnProbability
  * The Titan of Darkness is spawned on top of the player (at which point, the AI should give the player time to react),
  with a threat level of 9.

  The probability that the Titan of Darkness has spawned at least once after n minutes, assuming that all other
  conditions have been met, can be calculated using the formula P = 1 - (1 - spawnProbability) ^ math.floor(n / spawnAttemptInterval).
]]

local minSpawnCooldown  -- The amount of time to wait before spawning the Titan of Darkness again
local minPlanetStayTime  -- The player must have been on the current planet type for this amount of time
local worldTypeWhitelist  -- List of worlds on which the Titan of Darkness is allowed to spawn
local spawnAttemptInterval  -- How often the script should attempt to spawn the Titan
local spawnProbability  -- The chance of the spawn succeeding

local REQUIRED_DUNGEON_ID = 65535  -- Required dungeon ID for the Titan to spawn.

function init()
  minSpawnCooldown = 0
  minPlanetStayTime = 0
  worldTypeWhitelist = {"v-voltage", "v-toxicwasteland"}
  spawnAttemptInterval = 30
  spawnProbability = 0.05
end