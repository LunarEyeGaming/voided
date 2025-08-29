require "/scripts/vec2.lua"
require "/scripts/rect.lua"

require "/scripts/v-vec2.lua"
require "/scripts/v-ministarutil.lua"
require "/scripts/v-time.lua"

-- Invalidate global height map segments with:
-- /entityeval for x = 0, world.size()[1] // 32 do world.setProperty("v-globalHeightMap." .. x, nil) end

local cfg
local unmeltableMaterials

local entityHeightMaps

local liquidSurfacePoints
local nonOceanMaxReach  -- Maximum number of blocks that the light reaches when it is from a liquid not at minDepth
local surfaceProcessingLimit  -- Maximum number of surface points to process per tick.

local heatMap
local maxDepth  -- Depth that heats up the slowest
local minDepth  -- Depth that heats up the fastest. Also the depth at which the player takes the most burn damage.

local checkMinX
local checkMaxX
local checkMinY
local checkMaxY
local maxPenetration

local collisionSet
local nullCollisionSet
local blockOrNullCollisionSet
local sunLiquidId
local materialConfigs
local heatConfigs

local liquidScanner
local lightScanner

local isActive

local postInitCalled

local SECTOR_SIZE = 32

---@class RawHeightMap
---@field startXPos integer the starting horizontal position
---@field minHeight integer the minimum height to use
---@field list HeightMapItem[] the list of height map values.

---@alias HeightMapItem integer

---@class HeatedTile
---@field pos Vec2I
---@field heatTolerance number
---@field heat number
---@field heatDeltaDir number

function init()
  postInitCalled = false

  cfg = root.assetJson("/v-ministarheat.config")

  checkMinX = cfg.checkMinX
  checkMaxX = cfg.checkMaxX
  checkMinY = cfg.checkMinY
  checkMaxY = cfg.checkMaxY
  sunLiquidId = cfg.sunLiquidId

  minDepth = config.getParameter("minDepth")
  maxDepth = config.getParameter("maxDepth")

  initLiquidScanner()

  script.setUpdateDelta(6)

  -- Do not run this script on planets that are not of type "v-ministar," except for the liquid scanner - that will keep
  -- running.
  if world.type() ~= "v-ministar" then
    isActive = false
    return
  end

  isActive = true

  unmeltableMaterials = {}
  for _, material in ipairs(cfg.unmeltableMaterials) do
    unmeltableMaterials[material] = true
  end
  nonOceanMaxReach = cfg.nonOceanMaxReach
  surfaceProcessingLimit = cfg.surfaceProcessingLimit
  maxPenetration = cfg.maxPenetration  -- Maximum number of transparent blocks to penetrate.


  ---@type HeatedTile[]
  heatMap = {}
  entityHeightMaps = {}
  liquidSurfacePoints = {}
  collisionSet = {"Block", "Platform"}
  nullCollisionSet = {"Null"}
  blockOrNullCollisionSet = {"Block", "Null"}
  materialConfigs = {}
  heatConfigs = {}
  lightScanner = LightScanner:new{}

  message.setHandler("v-ministarheat-setEntityCollision", function(_, _, sourceId, heightMap)
    if heightMap then
      entityHeightMaps[sourceId] = vMinistar.XMap:fromJson(heightMap)
    else
      entityHeightMaps[sourceId] = nil
    end
  end)

  vTime.addInterval(cfg.entityHeightMapCleanUpInterval, function()
    for entityId, _ in pairs(entityHeightMaps) do
      if not world.entityExists(entityId) then
        entityHeightMaps[entityId] = nil
      end
    end
  end)

  vTime.addInterval(cfg.solarFlaresCleanUpInterval, function()
    local solarFlares = world.getProperty("v-solarFlares") or {}
    local time = world.time()

    -- Clean up expired entries
    for i = #solarFlares, 1, -1 do
      local flare = solarFlares[i]
      if time > flare.startTime + flare.duration then
        table.remove(solarFlares, i)
      end
    end

    -- If there are more than maxSolarFlares entries, delete the oldest entry repeatedly until there are maxSolarFlares
    -- entries.
    while #solarFlares > cfg.maxSolarFlares do
      table.remove(solarFlares, 1)
    end

    world.setProperty("v-solarFlares", solarFlares)
  end)

  -- Periodically cull liquidSurfacePoints chunks that are not in any player regions at the moment.
  vTime.addInterval(cfg.liquidSurfacePointsCleanUpInterval, function()
    local playerIds = world.players()

    -- Filter out nonexistent players.
    for i = #playerIds, 1, -1 do
      local playerId = playerIds[i]

      if not world.entityExists(playerId) then
        table.remove(playerIds, i)
      end
    end

    if #playerIds > 0 then
      -- Get query regions
      local positions = getPlayerPositions(playerIds)
      local regions = getPlayerRegions(positions)

      local liquidSurfacePointsNew = {}
      for _, region in ipairs(regions) do
        for chunkStr, tiles in pairs(liquidSurfacePoints) do
          local chunk = vVec2.iFromString(chunkStr)
          local chunkRect = {chunk[1] * 16, chunk[2] * 16, (chunk[1] + 1) * 16, (chunk[2] + 1) * 16}

          if rect.intersects(region, chunkRect) then
            liquidSurfacePointsNew[chunkStr] = tiles
          end
        end
      end
      liquidSurfacePoints = liquidSurfacePointsNew
    end
  end)
end

function initLiquidScanner()
  liquidScanner = LiquidScanner:new{
    liquidId = sunLiquidId,
    liquidThreshold = cfg.liquidScannerThreshold
  }

  -- Periodically mark all regions as "hot."
  vTime.addInterval(cfg.liquidScannerRefreshInterval, function()
    local playerIds = world.players()

    -- Filter out nonexistent players.
    for i = #playerIds, 1, -1 do
      local playerId = playerIds[i]

      if not world.entityExists(playerId) then
        table.remove(playerIds, i)
      end
    end

    if #playerIds > 0 then
      -- Get query regions
      local positions = getPlayerPositions(playerIds)
      local regions = getPlayerRegions(positions)
      local mergedRegions = mergeRegions(regions)

      liquidScanner:refresh(mergedRegions)
    end
  end)

  -- Mark other regions as "hot."
  message.setHandler("v-ministarheat-onTileModified", function(_, _, pos)
    liquidScanner:markRegionByTile(pos, 3)
  end)
end

function postInit()
  local stagehandId = world.loadUniqueEntity("v-ministarheat-stagehand")

  -- Set unique ID if no stagehand with that unique ID exists. Otherwise (if it is not the stagehand with the unique
  -- ID), die.
  if stagehandId == 0 then
    stagehand.setUniqueId("v-ministarheat-stagehand")
  elseif stagehandId ~= entity.id() then
    stagehand.die()
  end
end

function update(dt)
  if not postInitCalled then
    postInit()
    postInitCalled = true
    return
  end

  vTime.update(dt)

  local playerIds = world.players()

  -- Filter out nonexistent players.
  for i = #playerIds, 1, -1 do
    local playerId = playerIds[i]

    if not world.entityExists(playerId) then
      table.remove(playerIds, i)
    end
  end

  if #playerIds > 0 then
    local anchorPos = world.entityPosition(playerIds[1])  -- Anchor position to a player.

    -- Get query regions
    local positions = getPlayerPositions(playerIds)
    local regions = getPlayerRegions(positions)
    local mergedRegions = mergeRegions(regions)

    -- Run the main portion of the Ministar heat script if active. Otherwise, just run the liquid scanner.
    if isActive then
      prioritizeRegions(mergedRegions)

      local affectedTiles = {}  -- hash map
      local liquidTouchedTiles = {}  -- hash map
      local nonOceanAffectedTiles = {}  -- hash map of the tiles that were affected by liquids at a depth other than minDepth.
      local boostSets = {}  -- List of boosts for each region.

      -- Run liquid query on merged regions
      local boundaryTiles, particleSpawnPoints = liquidScanner:update(mergedRegions)

      -- Process particleSpawnPoints.
      for chunkStr, tiles in pairs(particleSpawnPoints) do
        if tiles == "clear" then
          liquidSurfacePoints[chunkStr] = nil
        elseif #tiles > 0 then
          liquidSurfacePoints[chunkStr] = tiles
        end
      end

      local vVec2_iToString = vVec2.iToString
      local world_pointTileCollision = world.pointTileCollision

      -- Update affectedTiles with the boundaryTiles that actually have foreground blocks.
      for _, tile in ipairs(boundaryTiles) do
        local tileStr = vVec2_iToString(tile)
        if not affectedTiles[tileStr] and world_pointTileCollision(tile) then
          affectedTiles[tileStr] = true
          liquidTouchedTiles[tileStr] = true
        end
      end

      local heightMaps = {}  -- Height maps for each region. Used for entity messaging.

      local combinedRayLocationsMaps = lightScanner:query(affectedTiles, nonOceanAffectedTiles)

      -- Abort if no rayLocationsMap is given. For now.
      if not combinedRayLocationsMaps then return end

      -- Run surface queries on merged regions
      for _, region in ipairs(mergedRegions) do
        -- Get the height map for the current player and add it to the list.
        local heightMap = oceanSurfaceQuery(region[1], region[3], region[2], region[4], affectedTiles)

        table.insert(heightMaps, heightMap)

        -- Calculate solar flare boosts for the current player and add it to the list.
        local boosts = vMinistar.computeSolarFlareBoosts(heightMap:xbounds())
        table.insert(boostSets, boosts)
      end

      -- for i, heightMap in ipairs(heightMaps) do
      --   heightMap:debug(stagehand.position()[2] + 20 + i * 8, 5, "green")
      -- end

      syncHeightMapsToGlobal(heightMaps)

      -- for i, heightMap in ipairs(heightMaps) do
      --   heightMap:debug(stagehand.position()[2] + i * 8, 5, "yellow")
      -- end
      applyEntityHeightMaps(heightMaps)

      local combinedHeightMap = vMinistar.XMap:merge(heightMaps)
      local combinedBoosts = vMinistar.XMap:merge(boostSets)

      -- Process existing entries.
      local tilesToDestroy = processHeatMap(affectedTiles, dt)

      -- Update information for v-ministareffects.lua
      for i, playerId in ipairs(playerIds) do
        local pos = positions[i]
        local region = regions[i]
        local sunProximityRatio = 1 - math.max(0, math.min((pos[2] - minDepth) / (maxDepth - minDepth), 1))
        local heightMap = combinedHeightMap:slice(region[1], region[3])
        local boosts = combinedBoosts:slice(region[1], region[3])
        local rayLocationsMap = combinedRayLocationsMaps:slice(region[1], region[3])
        -- sb.logInfo("%s, %s", region[1], region[3])
        -- TODO: Convert arguments into a table.
        world.sendEntityMessage(playerId, "v-ministareffects-updateBlocks", {
          heatMap = heatMap,
          heightMap = heightMap,
          sunProximityRatio = sunProximityRatio,
          minHeight = minDepth,
          liquidParticlePoints = particleSpawnPoints,
          flareBoosts = boosts,
          rayLocationsMap = rayLocationsMap
        })
        world.sendEntityMessage(playerId, "v-ministarheat-updateBlocks", heightMap, rayLocationsMap)
      end

      addToHeatMap(affectedTiles, combinedHeightMap, liquidTouchedTiles, nonOceanAffectedTiles, dt)

      -- Destroy tiles.
      world.damageTiles(tilesToDestroy, "foreground", {0, 0}, "blockish", 2 ^ 32 - 1, 0)
    else
      -- Query for liquids
      local _, particleSpawnPoints = liquidScanner:update(mergedRegions)

      -- Update information for v-ministareffects.lua
      for _, playerId in ipairs(playerIds) do
        world.sendEntityMessage(playerId, "v-ministareffects-updateLiquidParticles", particleSpawnPoints)
      end
    end

    stagehand.setPosition(anchorPos)
  end
end

---Returns a list of the positions (floored) of all existing players.
---@param playerIds EntityId[]
---@return Vec2I[]
function getPlayerPositions(playerIds)
  local positions = {}

  for _, playerId in ipairs(playerIds) do
    local playerPos = world.entityPosition(playerId)

    -- TODO: Remove this check as all players are guaranteed to exist at this point.
    if playerPos then
      local playerPosFloored = vec2.floor(playerPos)
      table.insert(positions, playerPosFloored)
    end
  end

  return positions
end

---Returns a list of regions surrounding each position in `positions`.
---@param positions Vec2I[]
---@return RectI[]
function getPlayerRegions(positions)
  local regions = {}

  for _, playerPos in ipairs(positions) do
    local region = {
      checkMinX + playerPos[1],
      checkMinY + playerPos[2],
      checkMaxX + playerPos[1],
      checkMaxY + playerPos[2]
    }
    table.insert(regions, region)
  end

  return regions
end

function mergeRegions(regions)
  if #regions < 2 then
    return regions
  end

  local rectNearestTo = function(source, target)
    local targetLl = rect.ll(target)
    return rect.translate(target, vec2.sub(world.nearestTo(rect.ll(source), targetLl), targetLl))
  end

  local rectArea = function(r)
    return (r[3] - r[1]) * (r[4] - r[2])
  end

  -- TODO: DON'T use a brute-force approach.
  -- Repeat ... until the number of regions has not changed.
  local newRegions = {}
  repeat
    -- For each pair of regions...
    for i = 1, #regions - 1 do
      for j = i + 1, #regions do
        local region1 = regions[i]
        local region2 = regions[j]
        region2 = rectNearestTo(region1, region2)

        local combinedRegion = {
          math.min(region1[1], region2[1]),
          math.min(region1[2], region2[2]),
          math.max(region1[3], region2[3]),
          math.max(region1[4], region2[4])
        }

        local intersectingRegion = {
          math.max(region1[1], region2[1]),
          math.max(region1[2], region2[2]),
          math.min(region1[3], region2[3]),
          math.min(region1[4], region2[4])
        }

        -- Calculate cost and benefit (cost is extra area incurred by combining the rectangles; benefit is area saved by
        -- combining them)
        local combinedArea = rectArea(combinedRegion)
        local intersectingArea = rectArea(intersectingRegion)
        local region1Area = rectArea(region1)
        local region2Area = rectArea(region2)
        local cost = combinedArea - (region1Area + region2Area - intersectingArea)
        local benefit = intersectingArea

        if benefit > cost then
          table.insert(newRegions, combinedRegion)
        else
          table.insert(newRegions, region1)
          table.insert(newRegions, region2)
        end
      end
    end
  until #newRegions == #regions

  return newRegions
end

---Sorts the regions by merge priority so that the resulting height maps merge properly. Regions with higher priorities
---are placed later in the list.
---
---Regions with y-max values < minDepth take the lowest priority and are collectively followed by regions with y-max
---values >= minDepth. Regions with y-max values >= minDepth are sorted among each other, in descending order, by their
---y-max values (so lower values take higher priority).
---@param regions RectI[]
function prioritizeRegions(regions)
  -- Sort regions in descending order.
  table.sort(regions, function(a, b) return a[4] > b[4] end)

  -- Find the index of the first value whose max y < minDepth
  local idx
  for i = 1, #regions do
    if regions[i][4] < minDepth then
      idx = i
      break
    end
  end

  -- If an index is found
  if idx then
    -- Take all elements from that index and onwards...
    local lowPriorityRegions = {}
    local nextRegion
    repeat
      nextRegion = table.remove(regions, idx)
      table.insert(lowPriorityRegions, nextRegion)  -- If nextElement is nil, this call has no effect.
    until not nextRegion

    -- ...and move them to the beginning of the list.
    for _, region in ipairs(lowPriorityRegions) do
      table.insert(regions, 1, region)
    end
  end
end

---Coroutine.
function nonOceanSurfaceQuery()
  local rayLocationsMap = vMinistar.XMap:new()
  local rayLocationsMap_list = rayLocationsMap.list
  local affectedTiles = {}
  local nonOceanAffectedTiles = {}

  local world_xwrap = world.xwrap
  local table_insert = table.insert
  local math_min = math.min
  local math_max = math.max
  local world_collisionBlocksAlongLine = world.collisionBlocksAlongLine
  local world_material = world.material
  local vVec2_iToString = vVec2.iToString

  local processSurfacePoint = function(tile)
    local tileX, tileY = tile[1], tile[2] - 1

    -- Skip if tileY == minDepth - 1
    if tileY ~= minDepth - 1 then
      -- Initialize entry if it is not initialized yet.
      local tileXWrapped = world_xwrap(tileX)
      local rayLocations = rayLocationsMap_list[tileXWrapped]
      if not rayLocations then
        rayLocations = {}
        rayLocationsMap_list[tileXWrapped] = rayLocations
      end

      local maxReach = tileY + nonOceanMaxReach
      local points = world_collisionBlocksAlongLine(tile, {tileX, maxReach}, collisionSet)

      -- Add to affectedTiles and nonOceanAffectedTiles all blocks in `points` that are below (or at the level of)
      -- the first solid, opaque block.
      local foundSolidTile = false
      for _, collideTile in ipairs(points) do
        local collideTileY = collideTile[2]

        local material = world_material(collideTile, "foreground")
        if material then
          -- This check takes advantage of the fact that we've already acquired the material.
          if not unmeltableMaterials[material] then
            local collideTileStr = vVec2_iToString(collideTile)
            affectedTiles[collideTileStr] = true
            local oldValue = nonOceanAffectedTiles[collideTileStr]
            nonOceanAffectedTiles[collideTileStr] = oldValue and math_min(oldValue, collideTileY - tileY) or collideTileY - tileY
          end

          local matCfg = getMaterialProperties(material)
          if matCfg and matCfg.isSolidAndOpaque or material == "metamaterial:structure" then
            -- world.debugLine({x, surfaceY}, {x, collideTile[2]}, "green")
            table_insert(rayLocations, {s = tileY, e = collideTileY})
            foundSolidTile = true
            break
          end
        end
      end

      -- Add to rayLocations the first solid, opaque block (or a y-value `nonOceanMaxReach` blocks above `surfaceY`
      -- if no such tile is found) as well as the `surfaceY`.
      if not foundSolidTile then
        -- world.debugLine({x, surfaceY}, {x, surfaceY + nonOceanMaxReach}, "red")
        table_insert(rayLocations, {s = tileY, e = maxReach})
      end
    end
  end

  -- Flatten liquidSurfacePoints list.
  local flattenedSurfacePoints = {}
  for _, tiles in pairs(liquidSurfacePoints) do
    table.move(tiles, 1, #tiles, #flattenedSurfacePoints + 1, flattenedSurfacePoints)
  end

  local numSurfacePoints = #flattenedSurfacePoints

  -- Process the points in steps.
  local startX = math.huge
  local endX = -math.huge
  for stride = 1, numSurfacePoints, surfaceProcessingLimit do
    local strideEnd = math_min(stride + surfaceProcessingLimit - 1, numSurfacePoints)

    for i = stride, strideEnd do
      local tile = flattenedSurfacePoints[i]
      processSurfacePoint(tile)
      startX = math_min(startX, tile[1])
      endX = math_max(endX, tile[2])
    end

    coroutine.yield()
  end

  rayLocationsMap.startXPos = startX
  rayLocationsMap.endXPos = endX

  return rayLocationsMap, affectedTiles, nonOceanAffectedTiles
end

-- ---Not a coroutine.
-- ---@param startX integer
-- ---@param endX integer
-- ---@param yTop integer
-- ---@param affectedTiles table<string, boolean>
-- ---@return VXMap
-- function oceanSurfaceQuery(startX, endX, yTop, affectedTiles)
---Not a coroutine.
---@param startX integer
---@param endX integer
---@param yBottom integer
---@param yTop integer
---@param affectedTiles table<string, boolean>
---@return VXMap
function oceanSurfaceQuery(startX, endX, yBottom, yTop, affectedTiles)
  -- If minDepth > yTop, abort this function call.
  if minDepth > yTop then
    return vMinistar.getHeightMap(startX, endX, minDepth)
  end

  local heightMap = vMinistar.XMap:new(startX, endX)
  local heightMap_list = heightMap.list

  -- local lowestSectors = findLowestLoadedSectors(startX, endX, yTop)
  -- -- Convert lowestSectors into a horizontal position map.
  -- local lowestSectorsMap = {}

  -- for _, sector in ipairs(lowestSectors) do
  --   local checkMinY = (sector[2] + 1) * SECTOR_SIZE
  --   -- Variant of checkMinY that stops at minDepth; whether or not the value was capped.
  --   local cappedCheckMinY, checkMinYWasCapped
  --   if checkMinY < minDepth then
  --     cappedCheckMinY = minDepth
  --     checkMinYWasCapped = true
  --   else
  --     cappedCheckMinY = checkMinY
  --     checkMinYWasCapped = false
  --   end
  --   local x = sector[1] * SECTOR_SIZE
  --   world.debugText("%s", checkMinY, {x, stagehand.position()[2] + x % 6}, "yellow")

  --   lowestSectorsMap[sector[1]] = {y = cappedCheckMinY, uncappedY = checkMinY, capped = checkMinYWasCapped}
  -- end

  local cappedCheckMinY
  local checkMinYWasCapped
  if yBottom < minDepth then
    cappedCheckMinY = minDepth
    checkMinYWasCapped = true
  else
    cappedCheckMinY = yBottom
    checkMinYWasCapped = false
  end

  local world_xwrap = world.xwrap
  local world_liquidAt = world.liquidAt
  local world_collisionBlocksAlongLine = world.collisionBlocksAlongLine
  local world_material = world.material
  local vVec2_iToString = vVec2.iToString

  -- Generate a set of tiles that are heated right now.
  for x = startX, endX do
    -- -- Find associated lowest sector.
    -- local xSector = x // SECTOR_SIZE
    -- local sectorValue = lowestSectorsMap[xSector]
    -- local cappedCheckMinY = sectorValue.y
    -- local checkMinYWasCapped = sectorValue.capped

    -- Proceed only if cappedCheckMinY is not actually capped or there is a liquid with ID sunLiquidId at the position
    -- directly below cappedCheckMinY.
    local shouldProceed = not checkMinYWasCapped
    if checkMinYWasCapped then
      local liquid = world_liquidAt({x, cappedCheckMinY - 1})
      if liquid and liquid[1] == sunLiquidId then
        shouldProceed = true
      end
    end

    -- world.debugText("%s, %s", yTop, cappedCheckMinY, {x, stagehand.position()[2] - 20 + x % 6 - yTop / 50}, "red")

    if shouldProceed and cappedCheckMinY <= yTop then
      local collidePoints = world_collisionBlocksAlongLine({x, cappedCheckMinY}, {x, yTop}, collisionSet, maxPenetration)

      -- Mark all tiles as affected. Stop after reaching the first solid, opaque tile.
      local foundSolidTile = false
      for _, collideTile in ipairs(collidePoints) do
        local material = world_material(collideTile, "foreground")
        if material then
          -- This check takes advantage of the fact that we've already acquired the material.
          if not unmeltableMaterials[material] then
            local collideTileStr = vVec2_iToString(collideTile)
            affectedTiles[collideTileStr] = true
          end
          local matCfg = getMaterialProperties(material)
          if matCfg and matCfg.isSolidAndOpaque or material == "metamaterial:structure" then
            -- Add to height map.
            heightMap_list[world_xwrap(x)] = collideTile[2]
            -- heightMap:set(x, collideTile[2])
            foundSolidTile = true
            break
          end
        end
      end

      -- Manually set the heightMap entry if no solid, opaque tile was found, or if collidePoints is empty.
      if not foundSolidTile then
        heightMap_list[world_xwrap(x)] = yTop
        -- heightMap:set(x, checkMaxY + pos[2])
        -- world.debugText("1", {x, stagehand.position()[2] - 20 + x % 6 - yTop / 50}, "yellow")
      end
    else
      heightMap_list[world_xwrap(x)] = cappedCheckMinY
        -- world.debugText("2", {x, stagehand.position()[2] - 20 + x % 6 - yTop / 50}, "red")
      -- heightMap:set(x, cappedCheckMinY)
    end
  end

  return heightMap
end

---Syncs the given height map to the global height map.
---@param heightMaps VXMap[]
function syncHeightMapsToGlobal(heightMaps)
  local math_floor = math.floor
  local world_xwrap = world.xwrap
  local world_getProperty = world.getProperty
  local world_pointTileCollision = world.pointTileCollision
  local world_liquidAt = world.liquidAt
  local world_setProperty = world.setProperty
  local table_insert = table.insert

  for _, heightMap in ipairs(heightMaps) do
    local startX, endX = heightMap:xbounds()
    local startXSector = startX // SECTOR_SIZE
    local endXSector = endX // SECTOR_SIZE
    sb.setLogMap("v-ministarheat(stagehand)_startXSector", "%s", startXSector)
    sb.setLogMap("v-ministarheat(stagehand)_endXSector", "%s", endXSector)

    -- Map from horizontal positions to `HeightMapItem`.
    ---@type table<integer, HeightMapItem>
    local globalHeightMap = {}
    -- For each `xSector` from `startXSector` to `endXSector`...
    for xSector = startXSector, endXSector do
      local xSectorWrapped = math_floor(world_xwrap(xSector * SECTOR_SIZE) // SECTOR_SIZE)
      -- Get global height map section corresponding to `xSector`.
      local globalHeightMapSection = world_getProperty("v-globalHeightMap." .. xSectorWrapped) or {}

      -- Copy the section over to globalHeightMap.
      for _, value in ipairs(globalHeightMapSection) do
        globalHeightMap[value.x] = value.value
      end
    end

    -- local stagehandPos = stagehand.position()
    -- for x, v in heightMap:xvalues() do
    --   world.debugText("x: %s\nlv: %s\ngv: %s\n", x, v, globalHeightMap[x], {x, stagehandPos[2] - 20 + 4 * (x % 5)}, "yellow")
    -- end

    -- For each entry in the list of `heightMap`...
    local heightMap_list = heightMap.list
    for x, v in heightMap:xvalues() do
      if not globalHeightMap[x] then
        globalHeightMap[x] = v
      else
        local globalV = globalHeightMap[x]
        -- If v < globalV or the region at globalV is loaded and that point is empty and either there is a liquid at minDepth - 1 or the position at minDepth - 1 is unloaded...
        if v < globalV or
          (not world_pointTileCollision({x, globalV}, blockOrNullCollisionSet) and
            (world_liquidAt({x, minDepth - 1}) or world_pointTileCollision({x, minDepth - 1}, nullCollisionSet))) then
          globalHeightMap[x] = v  -- Local value takes priority
          -- world.debugText("O", {x, stagehand.position()[2]}, "green")
        else
          heightMap_list[x] = globalV  -- Global value takes priority
          -- world.debugText("X", {x, stagehand.position()[2]}, "red")
        end
      end
    end

    -- Store globalHeightMap sections.
    -- For each `xSector` from `startXSector` to `endXSector`...
    for xSector = startXSector, endXSector do
      local globalHeightMapSection = {}
      local xSectorWrapped = math_floor(world_xwrap(xSector * SECTOR_SIZE) // SECTOR_SIZE)

      -- For each x value in the sector...
      for x = xSectorWrapped * SECTOR_SIZE, (xSectorWrapped + 1) * SECTOR_SIZE - 1 do
        -- Add to the section.
        table_insert(globalHeightMapSection, {x = x, value = globalHeightMap[x]})
      end

      world_setProperty("v-globalHeightMap." .. xSectorWrapped, globalHeightMapSection)
    end
  end
end

---Applies received entity height maps to the given `heightMaps`.
---@param heightMaps VXMap[]
function applyEntityHeightMaps(heightMaps)
  local flattenedEntityHeightMap = vMinistar.XMap:new()

  -- Merge entity height map values into one height map.
  for _, entityHeightMap in pairs(entityHeightMaps) do
    for x, v in entityHeightMap:xvalues() do
      local otherV = flattenedEntityHeightMap:get(x)
      if not otherV or v < otherV then
        flattenedEntityHeightMap:set(x, v)
      end
    end
  end

  -- Merge height maps with flattenedEntityHeightMap
  for _, heightMap in ipairs(heightMaps) do
    for x, v in heightMap:xvalues() do
      local otherV = flattenedEntityHeightMap:get(x)
      if otherV and otherV < v then
        heightMap:set(x, otherV)
      end
    end
  end
end

---Given a hash set of `affectedTiles`, updates `heatMap`. Each entry in `heatMap` that is also present in
---`affectedTiles` has its heat increased (decreased otherwise). Returns a list of tiles to destroy. Note: This also
---updates `affectedTiles` to exclude what was found in `heatMap`.
---@param affectedTiles table<string, boolean>
---@param dt number
---@return Vec2I[]
---@return {id: LiquidId, pos: Vec2I}[]
function processHeatMap(affectedTiles, dt)
  local vVec2_iToString = vVec2.iToString
  local table_insert = table.insert
  local table_remove = table.remove
  local world_pointTileCollision = world.pointTileCollision

  local tilesToDestroy = {}
  local liquidsToPlace = {}
  -- For each tile in the heatMap (iterated through backwards)...
  for i = #heatMap, 1, -1 do
    local tile = heatMap[i]
    local tilePos = tile.pos

    local tilePosHash = vVec2_iToString(tilePos)

    -- If the tile is in affectedTiles...
    if affectedTiles[tilePosHash] then
      tile.heat = tile.heat + dt
      tile.heatDeltaDir = 1

      if tile.heat > tile.heatTolerance then
        table_insert(tilesToDestroy, tilePos)
        table_remove(heatMap, i)
      end

      liquidScanner:markRegionByTile(tilePos, 3)

      -- Remove entry from affectedTiles to avoid excess inserts.
      affectedTiles[tilePosHash] = nil
    -- Otherwise, if the tile no longer exists...
    elseif not world_pointTileCollision(tilePos, collisionSet) then
      table_remove(heatMap, i)
    else
      tile.heat = tile.heat - dt
      tile.heatDeltaDir = -1

      if tile.heat <= 0 then
        table_remove(heatMap, i)
      end
    end
  end

  return tilesToDestroy, liquidsToPlace
end

---Adds `affectedTiles` to `heatMap` that are below the `maxDepth` value and are meltable.
---@param affectedTiles table<string, boolean>
---@param heightMap VXMap
---@param liquidTouchedTiles table<string, boolean> tiles touched by the sun liquid.
---@param nonOceanAffectedTiles table<string, integer>
---@param dt number
function addToHeatMap(affectedTiles, heightMap, liquidTouchedTiles, nonOceanAffectedTiles, dt)
  local vVec2_iFromString = vVec2.iFromString
  local world_material = world.material
  local table_insert = table.insert
  local math_min = math.min
  local math_max = math.max
  local math_huge = math.huge

  -- For each tile in `affectedTiles`...
  for tileHash, _ in pairs(affectedTiles) do
    local tile = vVec2_iFromString(tileHash)
    local tileY = tile[2]
    local material = world_material(tile, "foreground")

    local heightMapValue = heightMap:get(tile[1])
    -- Whether or not the affected tile is exposed (and therefore should be burned). Used to address false positives.
    local isExposed = not heightMapValue or minDepth <= tileY and tileY <= heightMapValue
    local nextToSunLiquid = liquidTouchedTiles[tileHash]
    local nonOceanDistance = nonOceanAffectedTiles[tileHash]
    -- local isExposed = true

    -- If there is a material at this tile, it is exposed or next to sun liquid, and it is not unmeltable...
    if material and (isExposed or nextToSunLiquid or nonOceanDistance) and not unmeltableMaterials[material] then
      -- Compute tolerance multiplier (tiles that are closer to minDepth have a lower heat tolerance). Capped at 0. This
      -- is immediately set to 0 if next to sun liquid. If exposed to non-ocean liquid as well, the minimum between the
      -- resulting values is computed.
      local toleranceMultiplier
      if nextToSunLiquid then
        toleranceMultiplier = 0
      else
        toleranceMultiplier = math_huge
        if nonOceanDistance then
          toleranceMultiplier = nonOceanDistance / nonOceanMaxReach
        end
        if isExposed then
          toleranceMultiplier = math_min(toleranceMultiplier, math_max(0, (tileY - minDepth) / (maxDepth - minDepth)))
        end
      end

      -- If the tolerance multiplier is at most 1...
      if toleranceMultiplier <= 1.0 then
        local heatCfg = getHeatConfig(material)
        local tolerance = heatCfg.tolerance * toleranceMultiplier ^ 2 + heatCfg.toleranceOffset
        table_insert(heatMap, {
          pos = tile,
          heat = 0,
          heatTolerance = tolerance > dt and tolerance or 0,
          heatDeltaDir = 1
        })
        -- world.debugPoint({tile[1] + 0.5, tile[2] + 0.5}, "yellow")

        liquidScanner:markRegionByTile(tile, 3)
      end
    end
  end
end

---Returns a list of the lowest sectors loaded between `xStart` and `xEnd` up to `yTop`.
---@param xStart number
---@param xEnd number
---@param yTop number
---@return Vec2I[]
function findLowestLoadedSectors(xStart, xEnd, yTop)
  local xSectorStart = xStart // SECTOR_SIZE
  local xSectorEnd = xEnd // SECTOR_SIZE
  local ySectorStart = yTop // SECTOR_SIZE

  local world_pointCollision = world.pointCollision
  local table_insert = table.insert

  local lowestSectors = {}

  -- local stagehandX = stagehand.position()[1]
  -- local stagehandY = stagehand.position()[2]
  -- local stagehandXSector = stagehandX // SECTOR_SIZE
  -- local stagehandYSector = stagehandY // SECTOR_SIZE
  -- For each column of sectors intersecting the area between xStart and xEnd...
  for xSector = xSectorStart, xSectorEnd do
    local x = xSector * SECTOR_SIZE

    local ySector = 0
    -- While the current sector is not loaded...
    -- while world.material({xSector * SECTOR_SIZE, ySector * SECTOR_SIZE}, "foreground") ~= nil do
    while world_pointCollision({x, ySector * SECTOR_SIZE}, nullCollisionSet) and ySector <= ySectorStart do
      -- world.debugPoint({stagehandX + (xSector - stagehandXSector), stagehandY + (ySector - stagehandYSector)}, "red")
      ySector = ySector + 1
    end
      -- world.debugPoint({stagehandX + (xSector - stagehandXSector), stagehandY + (ySector - stagehandYSector)}, "green")

    -- Add result to lowestSectors
    table_insert(lowestSectors, {xSector, ySector - 1})
  end

  return lowestSectors
end

---Gets the material config, caching what is relevant if it is not already cached.
---@param material string
---@return Json?
function getMaterialProperties(material)
  -- Register material if it is valid and is not already registered.
  if not materialConfigs[material] then
    local matConfigAndPath = root.materialConfig(material)
    if matConfigAndPath then
      local matConfig = matConfigAndPath.config
      materialConfigs[material] = {
        falling = matConfig.falling,
        footstepSound = matConfig.footstepSound,
        isSolidAndOpaque = not matConfig.renderParameters.lightTransparent and (matConfig.collisionKind or "solid") == "solid"
      }
    end
  end

  return materialConfigs[material]
end

function getHeatConfig(material)
  -- Build config if it is not cached already.
  if not heatConfigs[material] then
    local matCfg = getMaterialProperties(material)
    local default, inferred, override  -- inferred is from inferredTileConfigs (which are chosen based on footstep
                                       -- sound). override is from tileConfigs.
    default = {
      tolerance = cfg.defaultTolerance,
      toleranceOffset = 0
    }
    inferred = {}
    if matCfg then
      if matCfg.falling then
        default.tolerance = cfg.fallingTileDefaultTolerance
      end
      local footstepSound = matCfg.footstepSound
      -- sb.logInfo("footstepSound: %s", matCfg.footstepSound)
      if cfg.inferredTileConfigs[footstepSound] then
        inferred = cfg.inferredTileConfigs[footstepSound]
      end
    end
    override = cfg.tileConfigs[material] or {}
    -- sb.logInfo("inferredTileConfigs: %s", cfg.inferredTileConfigs)
    -- sb.logInfo("%s: default %s, inferred %s, override %s", material, default, inferred, override)

    heatConfigs[material] = sb.jsonMerge(sb.jsonMerge(default, inferred), override)
  end

  return heatConfigs[material]
end

------------------------------------------------HELPER CLASSES---------------------------------------------------

---@class VLiquidScanner
---@field _liquidId LiquidId
---@field _liquidThreshold number
---@field _CHUNK_SIZE integer
---@field _hotRegions table
---@field _prevLiquidChunks table
LiquidScanner = {}

---Instantiates a new liquid scanner.
---@param args table
---@return VLiquidScanner
function LiquidScanner:new(args)
  local instance = {
    _liquidId = args.liquidId,
    _liquidThreshold = args.liquidThreshold or 0,
    _CHUNK_SIZE = 16,
    _hotRegions = {},
    _prevLiquidChunks = {}
  }

  setmetatable(instance, self)
  self.__index = self

  return instance
end

---Attempts to runs a query in all regions `regions`, returning the tiles that are adjacent to the liquid with ID
---`_liquidId` and a list of particle spawn points for each chunk that was queried. Should be called every tick.
---
---@param regions RectI[]
---@return Vec2I[], table<string, Vec2I[] | "clear">
function LiquidScanner:update(regions)
  local world_liquidAt = world.liquidAt
  local world_liquidAlongLine = world.liquidAlongLine
  local vVec2_iToString2 = vVec2.iToString2
  local math_abs = math.abs

  local CHUNK_SIZE = self._CHUNK_SIZE
  local liquidId = self._liquidId
  local liquidThreshold = self._liquidThreshold
  local prevLiquidChunks = self._prevLiquidChunks
  local hotRegions = self._hotRegions

  local boundaryTiles = {}
  local liquidChunks = {}  -- Map of chunks to corresponding liquid values retrieved from world.liquidAt
  local particleSpawnPoints = {}  -- Map of chunks to lists of particle spawn points.

  for _, region in ipairs(regions) do
    local chunkMinX = region[1] // CHUNK_SIZE
    local chunkMinY = region[2] // CHUNK_SIZE
    local chunkMaxX = region[3] // CHUNK_SIZE
    local chunkMaxY = region[4] // CHUNK_SIZE

    for chunkX = chunkMinX, chunkMaxX do
      for chunkY = chunkMinY, chunkMaxY do
        local res = world_liquidAt({
          chunkX * CHUNK_SIZE - 1,
          chunkY * CHUNK_SIZE - 1,
          (chunkX + 1) * CHUNK_SIZE + 1,
          (chunkY + 1) * CHUNK_SIZE + 1
        })

        local chunkStr = vVec2_iToString2(chunkX, chunkY)

        liquidChunks[chunkStr] = res

        if not particleSpawnPoints[chunkStr] then
          particleSpawnPoints[chunkStr] = {}
        end
        local chunkPoints = particleSpawnPoints[chunkStr]

        -- Process the region in more detail if it is not completely filled with sun liquid and it is a hot region,
        -- solar plasma became the most plentiful liquid in the region, or the change in the total quantity since the
        -- last call to update is at least 1.
        if res and res[1] == liquidId and res[2] < 1.0 then
          local prevRes = prevLiquidChunks[chunkStr]
          if hotRegions[chunkStr] and hotRegions[chunkStr] > 0
              or (not prevRes or prevRes[1] ~= res[1] or math_abs(prevRes[2] - res[2]) * CHUNK_SIZE * CHUNK_SIZE >= 1) then
            local minXInChunk = chunkX * CHUNK_SIZE
            local minYInChunk = chunkY * CHUNK_SIZE
            local maxXInChunk = (chunkX + 1) * CHUNK_SIZE - 1
            local maxYInChunk = (chunkY + 1) * CHUNK_SIZE

            world.debugPoly({
              {minXInChunk, minYInChunk},
              {minXInChunk, maxYInChunk},
              {maxXInChunk, maxYInChunk},
              {maxXInChunk, minYInChunk}
            }, "green")

            -- Build matrix of matches and non-matches (row-major order). The matrix is padded for boundary cases.
            local liqMat = {}

            for y = minYInChunk - 1, maxYInChunk + 1 do
              local row = {}
              for x = minXInChunk - 1, maxXInChunk + 1 do
                row[x] = false
              end
              liqMat[y] = row
            end

            for x = minXInChunk - 1, maxXInChunk + 1 do
              local liqs = world_liquidAlongLine({x, minYInChunk - 1}, {x, maxYInChunk + 1})

              for _, posLiquidPair in ipairs(liqs) do
                local position = posLiquidPair[1]
                local liquid = posLiquidPair[2]
                liqMat[position[2]][position[1]] = liquid[1] == liquidId and liquid[2] >= liquidThreshold
              end
            end

            -- Find all of the tile spaces that act as boundaries for the liquid.
            for y = minYInChunk, maxYInChunk do
              local row = liqMat[y]
              for x = minXInChunk, maxXInChunk do
                local isSunLiquid = row[x]
                -- If the current space is sun liquid...
                if isSunLiquid then
                  -- Add all adjacent spaces that are not sun liquid.
                  if not row[x + 1] then
                    boundaryTiles[#boundaryTiles + 1] = {x + 1, y}
                  end
                  if not row[x - 1] then
                    boundaryTiles[#boundaryTiles + 1] = {x - 1, y}
                  end
                  if not liqMat[y + 1][x] then
                    boundaryTiles[#boundaryTiles + 1] = {x, y + 1}
                    chunkPoints[#chunkPoints + 1] = {x, y + 1}
                  end
                  if not liqMat[y - 1][x] then
                    boundaryTiles[#boundaryTiles + 1] = {x, y - 1}
                  end
                end
              end
            end
            -- Decrement hot region time remaining.
            if hotRegions[chunkStr] then
              hotRegions[chunkStr] = hotRegions[chunkStr] - 1
            end
          end

        else
          -- Mark this chunk to be cleared.
          particleSpawnPoints[chunkStr] = "clear"
        --   world.debugPoly({
        --     {chunkX * LIQUID_QUERY_CHUNK_SIZE, chunkY * LIQUID_QUERY_CHUNK_SIZE},
        --     {chunkX * LIQUID_QUERY_CHUNK_SIZE, (chunkY + 1) * LIQUID_QUERY_CHUNK_SIZE},
        --     {(chunkX + 1) * LIQUID_QUERY_CHUNK_SIZE, (chunkY + 1) * LIQUID_QUERY_CHUNK_SIZE},
        --     {(chunkX + 1) * LIQUID_QUERY_CHUNK_SIZE, chunkY * LIQUID_QUERY_CHUNK_SIZE}
        --   }, "red")
        end
      end
    end
  end

  self._prevLiquidChunks = liquidChunks

  return boundaryTiles, particleSpawnPoints
end

---Refreshes the entire nearby area, forcing the liquid scanner to requery it all next update.
---@param regions RectI[]
function LiquidScanner:refresh(regions)
  local CHUNK_SIZE = self._CHUNK_SIZE
  local hotRegions = self._hotRegions

  local vVec2_iToString2 = vVec2.iToString2

  for _, region in ipairs(regions) do
    local chunkMinX = region[1] // CHUNK_SIZE
    local chunkMinY = region[2] // CHUNK_SIZE
    local chunkMaxX = region[3] // CHUNK_SIZE
    local chunkMaxY = region[4] // CHUNK_SIZE

    for chunkX = chunkMinX, chunkMaxX do
      for chunkY = chunkMinY, chunkMaxY do
        local chunkStr = vVec2_iToString2(chunkX, chunkY)
        hotRegions[chunkStr] = 1
      end
    end
  end
end

---Marks a region as "hot" by the given tile for the given number of ticks.
---@param tile Vec2I
---@param time integer
function LiquidScanner:markRegionByTile(tile, time)
  local tileChunkStr = vVec2.iToString({tile[1] // self._CHUNK_SIZE, tile[2] // self._CHUNK_SIZE})
  self._hotRegions[tileChunkStr] = time
end

-- TODO: Rewrite to account for multiplayer.
---@class VLightScanner
LightScanner = {}

---Instantiates a new light scanner.
---@param args table
---@return VLightScanner
function LightScanner:new(args)
  local instance = {
    _rayLocationsMap = nil,
    _nonOceanSurfaceQueryCoroutine = coroutine.create(nonOceanSurfaceQuery)
  }

  setmetatable(instance, self)
  self.__index = self

  return instance
end

---Populates `affectedTiles` with a list of tiles that are exposed to the surface below given a central position `pos`.
---@param affectedTiles table<string, boolean>
---@param nonOceanAffectedTiles table<string, integer>
---@return VXMap rayLocationsMap
function LightScanner:query(affectedTiles, nonOceanAffectedTiles)
  -- Attempt to resume it.
  local status, rayLocationsMapOrErr, ownAffectedTiles, ownNonOceanAffectedTiles = coroutine.resume(self._nonOceanSurfaceQueryCoroutine)
  if not status then
    error(rayLocationsMapOrErr)
  end

  -- If the coroutine just died, restart it and update the values to return / move.
  if coroutine.status(self._nonOceanSurfaceQueryCoroutine) == "dead" then
    self._nonOceanSurfaceQueryCoroutine = coroutine.create(nonOceanSurfaceQuery)

    self._rayLocationsMap = rayLocationsMapOrErr
    self._ownAffectedTiles = ownAffectedTiles
    self._ownNonOceanAffectedTiles = ownNonOceanAffectedTiles
  end

  if self._ownAffectedTiles then
    for k, v in pairs(self._ownAffectedTiles) do
      affectedTiles[k] = v
    end

    for k, v in pairs(self._ownNonOceanAffectedTiles) do
      nonOceanAffectedTiles[k] = v
    end
  end

  return self._rayLocationsMap
end