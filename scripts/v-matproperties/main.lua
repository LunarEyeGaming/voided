require "/scripts/util.lua"
require "/scripts/vec2.lua"
require "/scripts/v-matproperties/sector.lua"

--[[
  A script that runs a framework based on v-matproperties.config to essentially hook scripts to matmods (materials not 
  supported). This is intended to be run solely in a generic script context.
]]

-- TODO: Consider the performance of loading hundreds of scripts.
local modFuncs
local matFuncs
local queriedModSectors
local lockedModSectors

local tickDelta
local tickTimer

local invalidationPeriod
local invalidationTimer

local sectorRange

function init()
  modFuncs = {}
  matFuncs = {}
  queriedModSectors = {}
  lockedModSectors = {}

  -- Initialize function lists.
  loadScripts()

  -- Parameters
  tickDelta = 4
  tickTimer = tickDelta

  invalidationPeriod = 1000 * 60
  
  sectorRange = 3  -- How many sectors to look (both horizontally and vertically) from the current sector.
  
  message.setHandler("tileBroken", handleBrokenTile)

  util.setDebug(true)
end

function update(dt)
  tickTimer = tickTimer - 1
  if tickTimer <= 0 then
    matUpdate(dt)
    tickTimer = tickDelta
  end
  
  -- Need to periodically invalidate the cached sectors because there is no known, event-driven method of checking for 
  -- placed tiles. This is probably as efficient as I can get.
  updateExpiry(dt)
  
  updateLockedSectors(dt)
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
  
  sb.logInfo("%s", modFuncs)  -- Debug statement.
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
  runUpdateHooks(dt)
  querySectors()
  cleanUpSectors()
  
  --world.debugText("number of cached sectors: %s", #queriedModSectors, mcontroller.position(), "green")
end

function updateExpiry(dt)
  for _, queriedSector in ipairs(queriedModSectors) do
    queriedSector.expiry = queriedSector.expiry - 1
  end
end

-- Updates the timers on all locked sectors and removes any whose times are 0 or less.
function updateLockedSectors(dt)
  local i = 1
  while i <= #lockedModSectors do
    local lockedSector = lockedModSectors[i]
    lockedSector.timer = lockedSector.timer - 1
    if lockedSector.timer < 0 then
      table.remove(lockedModSectors, i)
    else
      i = i + 1
    end
  end
end

--[[
  queriedModSectors schema:
    [
      {
        Sector sector
        MatMod[] matMods
        number expiry
      }
    ]
]]

-- Runs the update hook for each matmod applicable.
function runUpdateHooks(dt)
  -- support for materials not included yet.
  -- Go through each queried sector.
  for _, queriedSector in ipairs(queriedModSectors) do
    -- Go through each mat mod in the queried sector.
    for _, matMod in ipairs(queriedSector.matMods) do
      -- Check if modFuncs[matMod.name] exists because it is possible that modFuncs[matMod.name] doesn't exist due to an
      -- error and yet some mat mods are queried.
      if modFuncs[matMod.name] then
        -- Attempt to call the update hook.
        local status, result = pcall(modFuncs[matMod.name].update, matMod.pos, matMod.layer)
        
        -- If an error occurred...
        if not status then
          logScriptError(name, result)  -- Log the error
          modFuncs[name] = nil  -- Unload problematic script
        end
      end
      
      -- world.debugText("%s", matMod.name, matMod.pos, "green")
    end
  end
end

-- Queries sectors within proximity to the player that are both loaded and not already queried.
function querySectors()
  local matModsToQuery = util.keys(modFuncs)
  local ownPos = mcontroller.position()
  
  -- Go through the sectors close to the player.
  for sectorX = -sectorRange, sectorRange do
    for sectorY = -sectorRange, sectorRange do
      local sector = vec2.add(getSector(ownPos), {sectorX, sectorY})
      
      -- local pos1 = getPosFromSector(sector, {0, 0})
      -- local pos2 = getPosFromSector(sector, {32, 32})

      -- util.debugRect({pos1[1], pos1[2], pos2[1], pos2[2]}, isQueried(sector) and "green" or (isLoaded(sector) and "yellow" or "red"))

      -- If it is loaded and hasn't been queried yet, query it.
      if isLoaded(sector) and not isQueried(sector) and not isLocked(sector) then
        local result = querySector(sector, matModsToQuery)
        
        table.insert(queriedModSectors, {sector = sector, matMods = result, expiry = math.random(0, invalidationPeriod)})
      end
    end
  end
end

-- Clears unloaded or expired sectors that were queried
function cleanUpSectors()
  -- Use a while loop where i is incremented only when no item is deleted so that all items are deleted properly.
  local i = 1
  while i <= #queriedModSectors do
    -- If the sector at i is not loaded or has expired, delete it. Otherwise, increment i.
    if not isLoaded(queriedModSectors[i].sector) or queriedModSectors[i].expiry <= 0 then
      -- showInvalidatedSector(queriedModSectors[i].sector, 1.0)
      table.remove(queriedModSectors, i)
    else
      i = i + 1
    end
  end
end

--[[
  Removes a sector from queriedModSectors.
  
  param sector: the sector to remove
  returns: whether or not the sector was present
]]
function invalidateSector(sector)
  --sb.logInfo("Received invalidateSector call")
  for i, queriedSector in ipairs(queriedModSectors) do
    if vec2.eq(sector, queriedSector.sector) then
      -- Prototype for sector locking mechanism. If it hasn't already been locked, lock it so that it will not be
      -- queried by the system for a little bit.
      if not isLocked(sector) then
        lockSector(sector, 8)
      end
      --local entry = table.remove(queriedModSectors, i)
      --sb.logInfo("%s", entry)
      table.remove(queriedModSectors, i)
      return true
    end
  end
  
  return false
end

--[[
  Removes a MatMod at the given position and layer from the queriedModSectors list.
  param position: the position of the matmod to remove
  param layer: the layer of the matmod to remove
]]
function decacheMatMod(position, layer)
  -- find sector
  -- then find and remove the matmod itself
end

-- Returns true if the sector is in the queriedModSectors table and false otherwise.
function isQueried(sector)
  for _, matchedSector in ipairs(queriedModSectors) do
    if vec2.eq(sector, matchedSector.sector) then
      -- Stop and return true.
      return true
    end
  end
  
  return false
end

-- Returns true if the sector is in the lockedModSectors table and false otherwise.
function isLocked(sector)
  for _, lockedSector in ipairs(lockedModSectors) do
    if vec2.eq(sector, lockedSector.sector) then
      -- Stop and return true.
      return true
    end
  end
  
  return false
end

-- Locks a sector for a certain amount of time (measured in ticks). This stops the system from querying that sector.
function lockSector(sector, duration)
  table.insert(lockedModSectors, {sector = sector, timer = duration})
end

function handleBrokenTile(_, _, pos, layer)
  --sb.logInfo("Received tileBroken handler")
  runDestroyHook(pos, layer)
  invalidateSector(getSector(pos))
  
  -- showInvalidatedSector(getSector(pos), 0.5)
  -- sb.logInfo("invalidated: %s", invalidateSector(getSector(pos)))
end

function runDestroyHook(pos, layer)
  -- Exploits a loophole where the mod name does not get updated until after this function is called.
  local modName = world.mod(pos, layer)
  if modName and modFuncs[modName] then
    -- Call the destroy hook
    local status, result = pcall(modFuncs[modName].destroy, pos, layer)
    
    -- If an error occurred...
    if not status then
      logScriptError(modName, result)  -- Log the error
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

function showInvalidatedSector(sector, inwardThickness)
  local pos1 = getPosFromSector(sector, {0 + inwardThickness, 0 + inwardThickness})
  local pos2 = getPosFromSector(sector, {32 - inwardThickness, 32 - inwardThickness})

  util.debugRect({pos1[1], pos1[2], pos2[1], pos2[2]}, "blue")
end