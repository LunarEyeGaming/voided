require "/scripts/interp.lua"
require "/scripts/vec2.lua"
require "/scripts/rect.lua"

require "/scripts/v-vec2.lua"
require "/scripts/v-ministarutil.lua"
require "/scripts/statuseffects/v-tickdamage.lua"
require "/scripts/v-time.lua"

-- Invalidate global height map segments with:
-- /entityeval for x = 0, world.size()[1] // 32 do world.setProperty("v-globalHeightMap." .. x .. ".0", nil) end

local cfg
local unmeltableMaterials

local entityHeightMaps

local heatMap
local maxDepth  -- Depth that heats up the slowest
local minDepth  -- Depth that heats up the fastest. Also the depth at which the player takes the most burn damage.

local checkMinX
local checkMaxX
local checkMinY
local checkMaxY
local maxPenetration

local collisionSet
local sunLiquidId
local materialConfigs
local heatConfigs

local liquidScanner

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

  checkMinX = -100
  checkMaxX = 100
  checkMinY = -100
  checkMaxY = 100
  sunLiquidId = 218

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

  cfg = root.assetJson("/v-matattributes.config:ministarHeatConfig")
  unmeltableMaterials = {}
  for _, material in ipairs(cfg.unmeltableMaterials) do
    unmeltableMaterials[material] = true
  end

  ---@type HeatedTile[]
  heatMap = {}

  entityHeightMaps = {}

  message.setHandler("v-ministarheat-setEntityCollision", function(_, _, sourceId, heightMap)
    if heightMap then
      entityHeightMaps[sourceId] = vMinistar.HeightMap:fromJson(heightMap)
    else
      entityHeightMaps[sourceId] = nil
    end
  end)

  maxPenetration = 40  -- Maximum number of transparent blocks to penetrate.

  collisionSet = {"Block", "Platform"}
  materialConfigs = {}
  heatConfigs = {}

  vTime.addInterval(5, function()
    for entityId, _ in pairs(entityHeightMaps) do
      if not world.entityExists(entityId) then
        entityHeightMaps[entityId] = nil
      end
    end
  end)
end

function initLiquidScanner()
  liquidScanner = vMinistar.LiquidScanner:new{
    checkMinX = checkMinX,
    checkMaxX = checkMaxX,
    checkMinY = checkMinY,
    checkMaxY = checkMaxY,
    liquidId = sunLiquidId,
    liquidThreshold = 0.75
  }

  -- Periodically mark all regions as "hot."
  vTime.addInterval(5, function()
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

  -- Mark regions where tiles are broken as "hot."
  message.setHandler("tileBroken", function(_, _, pos, layer)
    if layer == "foreground" then
      liquidScanner:markRegionByTile(pos, 3)
    end
  end)

  -- Mark other regions as "hot."
  message.setHandler("v-ministarheat-onTileAdded", function(_, _, pos)
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
      local affectedTiles = {}  -- hash map
      local liquidTouchedTiles = {}  -- hash map
      local boostSets = {}  -- List of boosts for each region.

      -- Run liquid query on merged regions
      local boundaryTiles, particleSpawnPoints = liquidScanner:update(mergedRegions)

      -- Update affectedTiles with the boundaryTiles that actually have foreground blocks.
      for _, tile in ipairs(boundaryTiles) do
        local tileStr = vVec2.iToString(tile)
        if not affectedTiles[tileStr] and world.pointTileCollision(tile) then
          affectedTiles[tileStr] = true
          liquidTouchedTiles[tileStr] = true
        end
      end

      local heightMaps = {}  -- Height maps for each region. Used for entity messaging.

      -- Run surface queries on merged regions
      for _, region in ipairs(mergedRegions) do
        -- Get the height map for the current player and add it to the list.
        local heightMap = surfaceTileQuery(region[1], region[3], region[4], affectedTiles)
        table.insert(heightMaps, heightMap)

        -- Calculate solar flare boosts for the current player and add it to the list.
        local boosts = computeSolarFlareBoosts(heightMap:xbounds())
        table.insert(boostSets, boosts)
      end

      syncHeightMapsToGlobal(heightMaps)
      applyEntityHeightMaps(heightMaps)

      local combinedHeightMap = vMinistar.HeightMap:merge(heightMaps)
      local combinedBoosts = vMinistar.HeightMap:merge(boostSets)

      -- Process existing entries.
      local tilesToDestroy = processHeatMap(affectedTiles, dt)

      -- Update information for v-ministareffects.lua
      for i, playerId in ipairs(playerIds) do
        local pos = positions[i]
        local region = regions[i]
        local sunProximityRatio = 1 - math.max(0, math.min((pos[2] - minDepth) / (maxDepth - minDepth), 1))
        local heightMap = combinedHeightMap:slice(region[1], region[3])
        local boosts = combinedBoosts:slice(region[1], region[3])
        -- sb.logInfo("%s, %s", region[1], region[3])
        world.sendEntityMessage(playerId, "v-ministareffects-updateBlocks", heatMap, heightMap, sunProximityRatio, minDepth, particleSpawnPoints, boosts)
      end

      addToHeatMap(affectedTiles, combinedHeightMap, liquidTouchedTiles, dt)

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

---Populates `affectedTiles` with a list of tiles that are exposed to the surface below given a central position `pos`.
---@param startX integer
---@param endX integer
---@param yTop integer
---@param affectedTiles table<string, boolean>
---@param heightMap? HeightMap
---@return HeightMap
function surfaceTileQuery(startX, endX, yTop, affectedTiles, heightMap)
  local world_liquidAt = world.liquidAt
  local world_collisionBlocksAlongLine = world.collisionBlocksAlongLine
  local world_material = world.material
  local world_xwrap = world.xwrap
  local vVec2_iToString = vVec2.iToString

  heightMap = heightMap or vMinistar.HeightMap:new()

  -- Set x boundaries for the height map.
  heightMap.startXPos = world_xwrap(startX)
  heightMap.endXPos = world_xwrap(endX)

  local heightMap_list = heightMap.list

  local lowestSectors = findLowestLoadedSectors(startX, endX, yTop)

  -- Convert lowestSectors into a horizontal position map.
  local lowestSectorsMap = {}

  for _, sector in ipairs(lowestSectors) do
    local checkMinY = (sector[2] + 1) * SECTOR_SIZE
    -- Variant of checkMinY that stops at minDepth; whether or not the value was capped.
    local cappedCheckMinY, checkMinYWasCapped
    if checkMinY < minDepth then
      cappedCheckMinY = minDepth
      checkMinYWasCapped = true
    else
      cappedCheckMinY = checkMinY
      checkMinYWasCapped = false
    end
    lowestSectorsMap[sector[1]] = {y = cappedCheckMinY, capped = checkMinYWasCapped}
  end

  -- Generate a set of tiles that are heated right now.
  for x = startX, endX do
    -- Find associated lowest sector.
    local xSector = x // SECTOR_SIZE
    local sectorValue = lowestSectorsMap[xSector]
    local cappedCheckMinY = sectorValue.y
    local checkMinYWasCapped = sectorValue.capped

    -- Proceed only if cappedCheckMinY is not actually capped or there is a liquid with ID sunLiquidId at the position
    -- directly below cappedCheckMinY.
    local shouldProceed = not checkMinYWasCapped
    if checkMinYWasCapped then
      local liquid = world_liquidAt({x, cappedCheckMinY - 1})
      if liquid and liquid[1] == sunLiquidId then
        shouldProceed = true
      end
    end

    if shouldProceed then
      local collidePoints = world_collisionBlocksAlongLine({x, cappedCheckMinY}, {x, yTop}, collisionSet, maxPenetration)

      -- Mark all tiles as affected. Stop after reaching the first solid, opaque tile.
      local foundSolidTile = false
      for _, collideTile in ipairs(collidePoints) do
        local material = world_material(collideTile, "foreground")
        if material then
          local collideTileStr = vVec2_iToString(collideTile)
          affectedTiles[collideTileStr] = true
          local matCfg = getMaterialConfig(material)
          if matCfg and not matCfg.renderParameters.lightTransparent and matCfg.collisionKind == "solid" then
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
      end
    else
      heightMap_list[world_xwrap(x)] = cappedCheckMinY
      -- heightMap:set(x, cappedCheckMinY)
    end
  end

  return heightMap
end

---Syncs the given height map to the global height map.
---@param heightMaps HeightMap[]
function syncHeightMapsToGlobal(heightMaps)
  for _, heightMap in ipairs(heightMaps) do
    local startX, endX = heightMap:xbounds()
    local startXSector = startX // SECTOR_SIZE
    local endXSector = endX // SECTOR_SIZE
    sb.setLogMap("ministarheat_startXSector", "%s", startXSector)
    sb.setLogMap("ministarheat_endXSector", "%s", endXSector)

    -- Map from horizontal positions to `HeightMapItem`.
    ---@type table<integer, HeightMapItem>
    local globalHeightMap = {}
    -- For each `xSector` from `startXSector` to `endXSector`...
    for xSector = startXSector, endXSector do
      local xSectorWrapped = math.floor(world.xwrap(xSector * SECTOR_SIZE) // SECTOR_SIZE)
      -- Get global height map section corresponding to `xSector`.
      local globalHeightMapSection = world.getProperty("v-globalHeightMap." .. xSectorWrapped) or {}

      -- Copy the section over to globalHeightMap.
      for _, value in ipairs(globalHeightMapSection) do
        globalHeightMap[value.x] = value.value
      end
    end

    -- For each entry in the list of `heightMap`...
    -- for i, v in ipairs(heightMap.list) do
    --   local x = world.xwrap(i + heightMap.startXPos - 1)

    --   if not globalHeightMap[x] then
    --     globalHeightMap[x] = v
    --   else
    --     local globalV = globalHeightMap[x]

    --     local sharedValue
    --     if v < globalV or not world.pointCollision({x, globalV}, {"Null"}) then
    --       sharedValue = v
    --     else
    --       sharedValue = globalV
    --     end

    --     heightMap.list[i] = sharedValue
    --     globalHeightMap[x] = sharedValue
    --   end
    -- end

    -- local stagehandPos = stagehand.position()

    -- for x, v in heightMap:xvalues() do
    --   world.debugText("x: %s\nlv: %s\ngv: %s\n", x, v, globalHeightMap[x], {x, stagehandPos[2] + 10 + 4 * (x % 5)}, "green")
    -- end

    -- for sectorX = -10, 10 do
    --   for sectorY = -10, 10 do
    --     local displayX = stagehandPos[1] + sectorX
    --     local displayY = stagehandPos[2] + sectorY
    --     local x = stagehandPos[1] + sectorX * SECTOR_SIZE
    --     local y = stagehandPos[2] + sectorY * SECTOR_SIZE
    --     local color = world.pointCollision({x, y}, {"Null"}) and "red" or "green"

    --     world.debugPoint({displayX, displayY}, color)
    --   end
    -- end

    -- For each entry in the list of `heightMap`...
    for x, v in heightMap:xvalues() do
      if not globalHeightMap[x] then
        globalHeightMap[x] = v
      else
        local globalV = globalHeightMap[x]
        local sharedValue
        if v < globalV or not world.pointCollision({x, globalV}, {"Null"}) then
          sharedValue = v
        else
          sharedValue = globalV
        end
        heightMap:set(x, sharedValue)
        globalHeightMap[x] = sharedValue
      end
    end

    -- for x, v in heightMap:xvalues() do
    --   world.debugText("x: %s\nlv: %s\ngv: %s\n", x, v, globalHeightMap[x], {x, stagehandPos[2] - 20 + 4 * (x % 5)}, "yellow")
    -- end

    -- Store globalHeightMap sections.
    -- For each `xSector` from `startXSector` to `endXSector`...
    for xSector = startXSector, endXSector do
      local globalHeightMapSection = {}
      local xSectorWrapped = math.floor(world.xwrap(xSector * SECTOR_SIZE) // SECTOR_SIZE)

      -- For each x value in the sector...
      for x = xSectorWrapped * SECTOR_SIZE, (xSectorWrapped + 1) * SECTOR_SIZE - 1 do
        -- Add to the section.
        table.insert(globalHeightMapSection, {x = x, value = globalHeightMap[x]})
      end

      world.setProperty("v-globalHeightMap." .. xSectorWrapped, globalHeightMapSection)
    end
  end
end

---Applies received entity height maps to the given `heightMap`.
---@param heightMaps HeightMap[]
function applyEntityHeightMaps(heightMaps)
  local flattenedEntityHeightMap = vMinistar.HeightMap:new()

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
  local tilesToDestroy = {}
  local liquidsToPlace = {}
  -- For each tile in the heatMap (iterated through backwards)...
  for i = #heatMap, 1, -1 do
    local tile = heatMap[i]

    local tilePosHash = vVec2.iToString(tile.pos)

    -- If the tile is in affectedTiles...
    if affectedTiles[tilePosHash] then
      tile.heat = tile.heat + dt
      tile.heatDeltaDir = 1

      if tile.heat > tile.heatTolerance then
        table.insert(tilesToDestroy, tile.pos)
        if tile.liquidConversion then
          table.insert(liquidsToPlace, {id = tile.liquidConversion, pos = tile.pos})
        end
        table.remove(heatMap, i)
      end

      liquidScanner:markRegionByTile(tile.pos, 3)

      -- Remove entry from affectedTiles to avoid excess inserts.
      affectedTiles[tilePosHash] = nil
    -- Otherwise, if the tile no longer exists...
    elseif not world.pointTileCollision(tile.pos, collisionSet) then
      table.remove(heatMap, i)
    else
      tile.heat = tile.heat - dt
      tile.heatDeltaDir = -1

      if tile.heat <= 0 then
        table.remove(heatMap, i)
      end
    end
  end

  return tilesToDestroy, liquidsToPlace
end

---Adds `affectedTiles` to `heatMap` that are below the `maxDepth` value and are meltable.
---@param affectedTiles table<string, boolean>
---@param heightMap HeightMap
---@param liquidTouchedTiles table<string, boolean> tiles touched by the sun liquid.
---@param dt number
function addToHeatMap(affectedTiles, heightMap, liquidTouchedTiles, dt)
  -- For each tile in `affectedTiles`...
  for tileHash, _ in pairs(affectedTiles) do
    local tile = vVec2.iFromString(tileHash)
    local material = world.material(tile, "foreground")

    local heightMapValue = heightMap:get(tile[1])
    -- Whether or not the affected tile is exposed (and therefore should be burned). Used to address false positives.
    local isExposed = not heightMapValue or tile[2] <= heightMapValue
    local nextToSunLiquid = liquidTouchedTiles[tileHash]
    -- local isExposed = true

    -- If there is a material at this tile and it is exposed or next to sun liquid...
    if material and (isExposed or nextToSunLiquid) then
      -- Compute tolerance multiplier (tiles that are closer to minDepth have a lower heat tolerance). Capped at 0. This
      -- is immediately set to 0 if next to sun liquid.
      local toleranceMultiplier
      if nextToSunLiquid then
        toleranceMultiplier = 0
      else
        toleranceMultiplier = math.max(0, (tile[2] - minDepth) / (maxDepth - minDepth))
      end

      -- If the tolerance multiplier is at most 1 and the tile is not unmeltable...
      if not unmeltableMaterials[material] and toleranceMultiplier <= 1.0 then
        local heatCfg = getHeatConfig(material)
        local tolerance = heatCfg.tolerance * toleranceMultiplier ^ 2 + heatCfg.toleranceOffset
        table.insert(heatMap, {
          pos = tile,
          heat = 0,
          heatTolerance = tolerance > dt and tolerance or 0,
          heatDeltaDir = 1,
          liquidConversion = heatCfg.liquidConversion
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

  local lowestSectors = {}

  -- For each column of sectors intersecting the area between xStart and xEnd...
  for xSector = xSectorStart, xSectorEnd do
    local ySector = 0
    -- While the current sector is not loaded...
    -- while world.material({xSector * SECTOR_SIZE, ySector * SECTOR_SIZE}, "foreground") ~= nil do
    while world.pointCollision({xSector * SECTOR_SIZE, ySector * SECTOR_SIZE}, {"Null"}) and ySector <= ySectorStart do
      ySector = ySector + 1
    end

    -- Add result to lowestSectors
    table.insert(lowestSectors, {xSector, ySector - 1})
  end

  return lowestSectors
end

---Gets the material config, caching what is relevant if it is not already cached.
---@param material string
---@return Json?
function getMaterialConfig(material)
  -- Register material if it is valid and is not already registered.
  if not materialConfigs[material] then
    local matConfigAndPath = root.materialConfig(material)
    if matConfigAndPath then
      local matConfig = matConfigAndPath.config
      materialConfigs[material] = {
        falling = matConfig.falling,
        renderParameters = matConfig.renderParameters,
        footstepSound = matConfig.footstepSound,
        collisionKind = matConfig.collisionKind or "solid"
      }
    end
  end

  return materialConfigs[material]
end

function getHeatConfig(material)
  -- Build config if it is not cached already.
  if not heatConfigs[material] then
    local matCfg = getMaterialConfig(material)
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

---
---@param startX integer
---@param endX integer
---@return HeightMap
function computeSolarFlareBoosts(startX, endX)
  --[[
    Schema: {
      x: integer,  // Where the solar flare is located
      startTime: number,  // World time at which the solar flare started
      duration: number,  // How long the flare lasts.
      potency: number,  // Between 0 and 1. How potent the solar flare is.
      spread: number  // Controls the width of the solar flare.
    }[]
  ]]
  local solarFlares = world.getProperty("v-solarFlares") or {}
  local noFlareZones = world.getProperty("v-noFlareZones") or {}

  sb.setLogMap("solarFlares", "%s", #solarFlares)

  local boosts = vMinistar.HeightMap:new()
  for x = startX, endX do
    boosts:set(x, 0)
  end

  sb.setLogMap("boostsBounds", "%s %s", boosts.startXPos, boosts.endXPos)
  for _, flare in ipairs(solarFlares) do
    local durationStdDev = flare.duration / 6
    local durationMean = flare.startTime + flare.duration / 2
    local timeMultiplier = normalDistribution(durationMean, durationStdDev, world.time())

    for x = startX, endX do
      if not inNoFlareZone(x, noFlareZones) then
        boosts:set(x, boosts:get(x) + normalDistribution(flare.x, flare.spread / 3, x) * flare.potency * timeMultiplier)
      end
    end
  end

  return boosts
end

---Returns whether or not `x` is inside of a no-flare zone (with the no-flare zones given by `noFlareZones`).
---@param x integer
---@param noFlareZones {startX: integer, endX: integer}[]
---@return boolean
function inNoFlareZone(x, noFlareZones)
  for _, zone in ipairs(noFlareZones) do
    if zone.startX <= x and x <= zone.endX then
      return true
    end
  end

  return false
end

function normalDistribution(mean, stdDev, x)
  return math.exp(-(x - mean) ^ 2 / (2 * stdDev ^ 2))
end