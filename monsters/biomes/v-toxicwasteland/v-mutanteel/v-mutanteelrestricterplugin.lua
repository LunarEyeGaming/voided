--[[
  Script that makes it so that only one Mutant Eel may exist in a world at a time. This works by setting the world 
  property "v-activeMutantEel" to the current ID if it is not already set (or the corresponding entity does not exist)
  and otherwise kills itself it it is not the current ID. This is to be used by the mutant eel monster type 
  (particularly a base-level script). If any scripts loaded by the mutant eel override the init, update, or die hooks, 
  this script should be loaded after it.
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
  
  -- If the property has not been set or the entity does not exist...
  if not world.getProperty("v-activeMutantEel") or not world.entityExists(world.getProperty("v-activeMutantEel")) then
    world.setProperty("v-activeMutantEel", entity.id())
  -- Otherwise, if it has not despawned yet and this is not the current active eel...
  elseif not hasDespawned and world.getProperty("v-activeMutantEel") ~= entity.id() then
    status.setResourcePercentage("health", 0.0)
    mcontroller.setPosition({0, 0})
    hasDespawned = true
  end
end

function die()
  oldDie()
  
  -- If this is the active mutant eel and it has died, unset it.
  if world.getProperty("v-activeMutantEel") == entity.id() then
    world.setProperty("v-activeMutantEel", nil)
  end
end