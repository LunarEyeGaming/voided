--[[
  Script that makes it so that only one Titan may exist in a world at a time and that it can spawn only inside of
  regions with dungeon IDs 65535 or 65533. This works by running a check for all dungeon IDs within the entity's
  bounding box immediately after spawning. It immediately despawns if any dungeon ID is not 65535 or 65533. If it does
  not have a uniqueId, it then sets its uniqueId to "v-titanofdarkness" if an entity with that uniqueId does not exist,
  otherwise killing itself. This is to be used by the Titan's monster type (particularly a base-level script). If any
  scripts loaded by the Titan override the init, update, or die hooks, this script should be loaded after it.
]]

require "/scripts/rect.lua"

require "/scripts/v-world.lua"

local oldInit = init or function() end

function init()
  -- If the Titan does not have a uniqueId assigned...
  if not entity.uniqueId() then
    -- Find the entity with uniqueId "v-titanofdarkness"
    local titanId = world.loadUniqueEntity("v-titanofdarkness")

    -- If there is one...
    if titanId ~= 0 then
      -- Disappear.
      monster.setUniqueId()
      status.setResourcePercentage("health", 0.0)
      monster.setDropPool(nil)
      self.shouldDie = true
      script.setUpdateDelta(0)  -- Suppress calls to update

      return
    else
      monster.setUniqueId("v-titanofdarkness")
    end
  end

  -- If the Titan is not in a monster spawn zone (and spawnAnywhere is false)...
  if not config.getParameter("spawnAnywhere") and not vWorld.canSpawnMonster(mcontroller.boundBox(), mcontroller.position()) then
    -- Disappear.
    monster.setUniqueId()
    status.setResourcePercentage("health", 0.0)
    monster.setDropPool(nil)
    self.shouldDie = true
    script.setUpdateDelta(0)  -- Suppress calls to update

    return  -- Don't initialize
  end

  oldInit()
end