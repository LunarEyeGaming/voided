--[[
  Script that makes it so that only one Titan may exist in a world at a time and that it can spawn only inside of
  regions with dungeon ID 65535. This works by running a check for all dungeon IDs within the entity's bounding box
  immediately after spawning. It immediately despawns if any dungeon ID is not 65535. It then sets the world property
  "v-activeTitanOfDarkness" to the current ID if it is not already set (or the corresponding entity does not exist)
  and otherwise kills itself it it is not the current ID. This is to be used by the Titan's monster type (particularly a
  base-level script). If any scripts loaded by the Titan override the init, update, or die hooks, this script should be
  loaded after it.
]]

require "/scripts/rect.lua"

local oldInit = init or function() end
local oldUpdate = update or function() end
local oldDie = die or function() end

local hasDespawned
local REQUIRED_DUNGEON_ID = 65535

function init()
  oldInit()

  hasDespawned = false

  if not isInMonsterSpawnZone() then
    status.setResourcePercentage("health", 0.0)
    monster.setDropPool(nil)
    self.shouldDie = true
    mcontroller.setPosition({0, 0})
    hasDespawned = true
  end
end

function update(dt)
  oldUpdate(dt)

  local titanId = world.getProperty("v-activeTitanOfDarkness")
  -- If the property has not been set or the entity does not exist...
  if not titanId or not world.entityExists(titanId) then
    world.setProperty("v-activeTitanOfDarkness", entity.id())
  -- Otherwise, if it has not despawned yet and this is not the current active Titan...
  elseif not hasDespawned and titanId ~= entity.id() then
    status.setResourcePercentage("health", 0.0)
    monster.setDropPool(nil)
    self.shouldDie = true
    mcontroller.setPosition({0, 0})
    hasDespawned = true
  end
end

function die()
  oldDie()

  -- If this is the active Titan and it has died, unset it.
  if world.getProperty("v-activeTitanOfDarkness") == entity.id() then
    world.setProperty("v-activeTitanOfDarkness", nil)
  end
end

---Returns `true` if all spaces that the player's bounding box occupies have a dungeon ID of REQUIRED_DUNGEON_ID,
---`false` otherwise.
---@return boolean
function isInMonsterSpawnZone()
  local boundBox = rect.translate(mcontroller.boundBox(), mcontroller.position())

  for x = boundBox[1], boundBox[3] do
    for y = boundBox[2], boundBox[4] do
      if world.dungeonId({x, y}) ~= REQUIRED_DUNGEON_ID then
        return false
      end
    end
  end

  return true
end