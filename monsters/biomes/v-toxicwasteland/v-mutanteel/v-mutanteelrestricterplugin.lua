--[[
  Script that makes it so that only one wild Mutant Eel may exist in a world at a time. This works by setting the world
  property "v-activeMutantEel" to the current ID if it is not already set (or the corresponding entity does not exist)
  and otherwise kills itself it it is not the current ID. This is to be used by the mutant eel monster type
  (particularly a base-level script). If any scripts loaded by the mutant eel override the init, update, or die hooks,
  this script should be loaded after it. This check is disabled if the eel is captured (and is thus not "wild").
]]

local oldInit = init or function() end
local oldUpdate = update or function() end
local oldDie = die or function() end

local hasDespawned

function init()
  oldInit()

  hasDespawned = false
end

function update(dt)
  oldUpdate(dt)

  -- Check for an active mutant eel only if this is a wild one.
  if not capturable or not capturable.podUuid() then
    local eelId = world.getProperty("v-activeMutantEel")
    -- If the property has not been set or the entity does not exist...
    if not eelId or not world.entityExists(eelId) then
      world.setProperty("v-activeMutantEel", entity.id())
    -- Otherwise, if it has not despawned yet and this is not the current active eel...
    elseif not hasDespawned and eelId ~= entity.id() then
      status.setResourcePercentage("health", 0.0)
      monster.setDropPool(nil)
      mcontroller.setPosition({0, 0})
      hasDespawned = true
    end
  end
end

function die()
  oldDie()

  -- If this is the active mutant eel and it has died, unset it.
  if world.getProperty("v-activeMutantEel") == entity.id() then
    world.setProperty("v-activeMutantEel", nil)
  end
end