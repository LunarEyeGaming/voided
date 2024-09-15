require "/scripts/util.lua"
require "/scripts/vec2.lua"
require "/scripts/v-matproperties/sector.lua"
require "/scripts/v-vec2.lua"

--[[
  A script that runs a framework based on v-matproperties.config to essentially hook scripts to matmods (materials not
  supported). This is intended to be run solely in a generic script context.
]]

-- TODO: Consider the performance of loading hundreds of scripts.
local modFuncs
local matFuncs
local queriedModSectors
local queriedModSectorSet
local lockedModSectors
local claimedModSectors

local tickDelta
local tickTimer

local invalidationTimeRange

local sectorRange

local claimBroadcastRange

function init()
  modFuncs = {}
  matFuncs = {}
  queriedModSectors = {}
  queriedModSectorSet = {}
  lockedModSectors = {}
  claimedModSectors = {}

  -- Initialize function lists.
  loadScripts()

  -- Parameters
  tickDelta = 4
  tickTimer = tickDelta

  invalidationTimeRange = {15 * 60, 30 * 60}

  sectorRange = 3  -- How many sectors to look (both horizontally and vertically) from the current sector.

  claimBroadcastRange = (sectorRange + 1) * SECTOR_SIZE

  message.setHandler("tileBroken", handleBrokenTile)

  message.setHandler("v-updateSector", function(_, _, sector)
    invalidateSector(sector)
  end)

  message.setHandler("v-updateRegion", function(_, _, region)
    local sectors = getSectorsInRegion(region)

    for _, sector in ipairs(sectors) do
      invalidateSector(sector)
    end
  end)

  message.setHandler("v-claimSector", function(_, _, sector, duration, playerId)
    -- Arbitrary condition to ensure that no more than one player keeps a sector.
    if isQueried(sector) and playerId > player.id() then
      invalidateSector(sector)
    end

    table.insert(claimedModSectors, {sector = sector, expiry = duration})
  end)

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

  -- sb.logInfo("%s", modFuncs)  -- Debug statement.
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
  cleanUpClaimedSectors()

  -- world.debugText("number of cached sectors: %s", #queriedModSectors, mcontroller.position(), "green")
end

function updateExpiry(dt)
  for _, queriedSector in ipairs(queriedModSectors) do
    queriedSector.expiry = queriedSector.expiry - 1
  end

  for _, claimedSector in ipairs(claimedModSectors) do
    -- local sector = claimedSector.sector

    -- local pos1 = getPosFromSector(sector, {0, 0})
    -- local pos2 = getPosFromSector(sector, {32, 32})

    -- util.debugRect({pos1[1], pos1[2], pos2[1], pos2[2]}, "blue")

    claimedSector.expiry = claimedSector.expiry - 1
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
          logScriptError(matMod.name, result)  -- Log the error
          modFuncs[matMod.name] = nil  -- Unload problematic script
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

      -- If it is loaded, it hasn't been queried yet, and it was not locked, query it
      if isLoaded(sector) and not isQueried(sector) and not isLocked(sector) and not isClaimed(sector) then
        local result = querySector(sector, matModsToQuery)

        local expiry = math.random(invalidationTimeRange[1], invalidationTimeRange[2])

        claimSector(sector, expiry)

        table.insert(queriedModSectors, {sector = sector, matMods = result, expiry = expiry})
        queriedModSectorSet[vVec2.iToString(sector)] = true  -- Insert into set
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
    if not isLoaded(queriedModSectors[i].sector) or queriedModSectors[i].expiry < 0 then
      -- showInvalidatedSector(queriedModSectors[i].sector, 1.0)
      queriedModSectorSet[vVec2.iToString(queriedModSectors[i].sector)] = nil  -- Remove from set
      table.remove(queriedModSectors, i)
    else
      i = i + 1
    end
  end
end

-- Clears unloaded or expired sectors that were claimed
function cleanUpClaimedSectors()
  -- Use a while loop where i is incremented only when no item is deleted so that all items are deleted properly.
  local i = 1
  while i <= #claimedModSectors do
    -- If the sector at i has expired, delete it. Otherwise, increment i.
    if claimedModSectors[i].expiry < 0 then
      -- showInvalidatedSector(queriedModSectors[i].sector, 1.0)
      table.remove(claimedModSectors, i)
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
      queriedModSectorSet[vVec2.iToString(queriedModSectors[i].sector)] = nil  -- Remove from set
      table.remove(queriedModSectors, i)
      return true
    end
  end

  return false
end

-- Returns true if the sector is in the `queriedModSectorSet` table and false otherwise.
function isQueried(sector)
  -- for _, matchedSector in ipairs(queriedModSectors) do
  --   if vec2.eq(sector, matchedSector.sector) then
  --     -- Stop and return true.
  --     return true
  --   end
  -- end

  -- return false
  return queriedModSectorSet[vVec2.iToString(sector)] ~= nil
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

-- Returns true if the sector is in the claimedModSectors table and false otherwise.
function isClaimed(sector)
  for _, claimedSector in ipairs(claimedModSectors) do
    if vec2.eq(sector, claimedSector.sector) then
      -- Stop and return true
      return true
    end
  end

  return false
end

-- Locks a sector for a certain amount of time (measured in ticks). This stops the system from querying that sector.
function lockSector(sector, duration)
  table.insert(lockedModSectors, {sector = sector, timer = duration})
end

-- Claims a sector, preventing other nearby players from being able to query it until it expires.
function claimSector(sector, duration)
  local broadcastPoint1 = vec2.add(mcontroller.position(), {-claimBroadcastRange, -claimBroadcastRange})
  local broadcastPoint2 = vec2.add(mcontroller.position(), {claimBroadcastRange, claimBroadcastRange})

  local queried = world.entityQuery(broadcastPoint1, broadcastPoint2, {includedTypes = {"player"}})

  for _, id in ipairs(queried) do
    -- If the given ID is not the current player, send a message that this sector is claimed.
    if player.id() ~= id then
      world.sendEntityMessage(id, "v-claimSector", sector, duration, player.id())
    end
  end
end

function handleBrokenTile(_, _, pos, layer)
  --sb.logInfo("Received tileBroken handler")
  -- This function only triggers for the person who mined it, so there isn't any need to check if the sector
  -- corresponding to pos is claimed.
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