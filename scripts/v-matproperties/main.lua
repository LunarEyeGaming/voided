require "/scripts/util.lua"
require "/scripts/vec2.lua"

-- TODO: Consider the performance of loading hundreds of scripts.
local modFuncs
local matFuncs

local tickDelta
local tickTimer
local queryRange

local sectorRange

function init()
  modFuncs = {}
  matFuncs = {}
  matchedMods = {}

  -- Initialize function lists.
  loadScripts()
  
  -- Parameters
  tickDelta = 4
  tickTimer = tickDelta
  queryRange = 60  -- Matter manipulator can reach 17 blocks away at most, and there is a planned increase of up to 25 blocks.
  
  -- New query system parameters
  sectorRange = 2  -- How many sectors to look from the current sector.
  
  message.setHandler("tileBroken", handleBrokenTile)

  queryMats()
end

function update(dt)
  tickTimer = tickTimer - 1
  if tickTimer <= 0 then
    matUpdate(dt)
    tickTimer = tickDelta
  end
end

-- HELPER FUNCTIONS

function loadScripts()
  -- Load scripts
  local matProperties = root.assetJson("/v-matproperties.config")
  
  -- Go through matmod scripts.
  for name, path in pairs(matProperties.matModScripts) do
    
    local status, result = pcall(loadScript, name, path)
    
    if not status then
      logLoadingError(path, result)
    end
  end
  
  sb.logInfo("%s", modFuncs)
end

function loadScript(name, path)
  require(path)
  
  -- If no ModProperty table exists, log it as an error. Otherwise, load it.
  if not ModProperty then
    logLoadingError(path, "Could not find 'ModProperty' table")
  else
    -- Save into the mod function list for later calling.
    modFuncs[name] = {
      update = ModProperty.update or function() end,
      destroy = ModProperty.destroy or function() end
    }
  end
end

function matUpdate(dt)
  -- support for materials not included yet.
  
  for name, modLocations in pairs(matchedMods) do
    if modFuncs[name] then
      for _, location in ipairs(modLocations) do
        local modPos, modLayer = table.unpack(location)
        
        local status, result = pcall(modFuncs[name].update, modPos, modLayer)
        
        -- If an error occurred...
        if not status then
          logScriptError(name, result)
          modFuncs[name] = nil  -- Unload problematic script
          
          break  -- Stop to avoid calling modFuncs[name].update again.
        end
      end
    end
  end
end

--[[
  matchedMods schema:
    <modName>: [
      [<modPosition (vec2)>, <modLayer (string)>]
    ]
]]

function queryMats()
  local ownPos = mcontroller.position()

  matchedMods = {}

  for x = -queryRange, queryRange do
    for y = -queryRange, queryRange do
      local modPos = vec2.add({x, y}, ownPos)

      -- Query for a foreground mod and a background matmod. In both cases, if it is scripted, store its position and 
      -- layer.
      local foregroundMod = world.mod(modPos, "foreground")
      if foregroundMod and modFuncs[foregroundMod] then
        if not matchedMods[foregroundMod] then
          matchedMods[foregroundMod] = {}
        end
        table.insert(matchedMods[foregroundMod], {modPos, "foreground"})
      end
      
      local backgroundMod = world.mod(modPos, "background")
      if backgroundMod and modFuncs[backgroundMod] then
        if not matchedMods[backgroundMod] then
          matchedMods[backgroundMod] = {}
        end
        table.insert(matchedMods[backgroundMod], {modPos, "background"})
      end
    end
  end
end


function handleBrokenTile(_, _, pos, layer)
  -- Exploits a loophole where the mod name does not get updated until after this function is called.
  local modName = world.mod(pos, layer)
  if modName and modFuncs[modName] then
    local status, result = pcall(modFuncs[modName].destroy, pos, layer)
    
    -- If an error occurred...
    if not status then
      logScriptError(modName, result)
      modFuncs[modName] = nil  -- Unload problematic script
    end
  end
end

function logLoadingError(path, msg)
  sb.logError("Error loading %s: %s", path, msg)
end

function logScriptError(name, msg)
  sb.logError("Error running script corresponding to '%s': %s", name, msg)
end