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

local burnDepth  -- Depth at which the player starts burning
local minBurnDamage
local maxBurnDamage
local tickTime

local tickDamage

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

-- local undergroundTileQueryThread

local celestialParamsFetched

local ADJACENT_TILES = {{1, 0}, {0, 1}, {-1, 0}, {0, -1}}
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
  checkMinX = -100
  checkMaxX = 100
  checkMinY = -100
  checkMaxY = 100
  sunLiquidId = 218

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

  minBurnDamage = 1
  maxBurnDamage = 20
  tickTime = 0.5

  tickDamage = VTickDamage:new{ kind = "fire", amount = minBurnDamage, damageType = "IgnoresDef", interval = tickTime, source = player.id() }

  maxPenetration = 40  -- Maximum number of transparent blocks to penetrate.

  collisionSet = {"Block", "Platform"}
  materialConfigs = {}
  heatConfigs = {}

  celestialParamsFetched = false

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
    local pos = vec2.floor(mcontroller.position())
    liquidScanner:refresh(pos)
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

function fetchCelestialParams()
  -- Initialize depth-related parameters
  local coords = getCelestialCoordinates()
  if coords then
    local celestialParams = celestial.visitableParameters(coords)  --[[@as VisitableParameters]]
    if celestialParams then
      maxDepth = celestialParams.spaceLayer.layerMinHeight
      minDepth = celestialParams.surfaceLayer.primarySubRegion.oceanLiquidLevel
      burnDepth = (minDepth + maxDepth) / 2

      message.setHandler("v-ministarheat-getSpawnRange", function()
        return {celestialParams.atmosphereLayer.layerMinHeight, maxDepth}
      end)

      celestialParamsFetched = true
    end
  else
    maxDepth = 2000
    minDepth = 1000
    -- minDepth = 990
    burnDepth = 1500

    message.setHandler("v-ministarheat-getSpawnRange", function()
      return {1400, maxDepth}
    end)

    celestialParamsFetched = true
  end
end

function update(dt)
  vTime.update(dt)

  -- Run the main portion of the Ministar heat script if active. Otherwise, just run the liquid scanner.
  if isActive then
    -- Need to try fetching celestial parameters repeatedly because celestial.visitableParameters returns nil until
    -- shortly after the world is created (as opposed to immediately afterwards).
    if not celestialParamsFetched then
      fetchCelestialParams()
      return
    end

    local pos = vec2.floor(mcontroller.position())
    local affectedTiles = {}  -- hash map

    local boundaryTiles, particleSpawnPoints = liquidScanner:update(pos)

    -- Update affectedTiles with the boundaryTiles that actually have foreground blocks.
    for _, tile in ipairs(boundaryTiles) do
      local tileStr = vVec2.iToString(tile)
      if not affectedTiles[tileStr] and world.pointTileCollision(tile) then
        affectedTiles[tileStr] = true
      end
    end

    local heightMap = surfaceTileQuery(pos, affectedTiles)

    syncHeightMapToGlobal(heightMap)

    applyEntityHeightMaps(heightMap)

    -- Process existing entries.
    local tilesToDestroy = processHeatMap(affectedTiles, dt)

    -- Calculate solar flare boosts.
    local boosts = computeSolarFlareBoosts(heightMap:xbounds())

    -- Update heatMap for v-ministareffects.lua
    local sunProximityRatio = 1 - math.max(0, math.min((pos[2] - minDepth) / (maxDepth - minDepth), 1))
    world.sendEntityMessage(player.id(), "v-ministareffects-updateBlocks", heatMap, heightMap, sunProximityRatio, minDepth, particleSpawnPoints, boosts)

    addToHeatMap(affectedTiles, heightMap, dt)

    -- Destroy tiles.
    world.damageTiles(tilesToDestroy, "foreground", mcontroller.position(), "blockish", 2 ^ 32 - 1, 0)

    local burnRatio = (1 - (pos[2] - minDepth) / (burnDepth - minDepth)) + boosts:get(pos[1])

    sb.setLogMap("burnRatio", "%s", burnRatio)

    if status.statPositive("v-ministarHeatTickMultiplier") then
      tickDamage.interval = tickTime * status.stat("v-ministarHeatTickMultiplier")
    end

    local multiplier = 1 - status.stat("v-ministarHeatResistance")

    -- If the player should be burned...
    if burnRatio > 0.0 and isExposedForeground(heightMap) and multiplier > 0.0 then
      -- Update damage amount. It is a linear interpolation between maxBurnDamage and minBurnDamage, where damage grows as
      -- depth (aka y position) decreases.
      tickDamage.damageRequest.damage = interp.linear(burnRatio, minBurnDamage, maxBurnDamage) * multiplier
      tickDamage:update(dt)  -- Run the tickDamage object for one tick.
    else
      tickDamage:reset()
    end
  else
    local pos = vec2.floor(mcontroller.position())
    local _, particleSpawnPoints = liquidScanner:update(pos)
    world.sendEntityMessage(player.id(), "v-ministareffects-updateLiquidParticles", particleSpawnPoints)
  end
end

---Returns celestial coordinates for the current world, if it is a celestial world. Returns `nil` otherwise.
---@return CelestialCoordinate?
function getCelestialCoordinates()
  local worldId = player.worldId()
  local first, last, x, y, z, planet = worldId:find("CelestialWorld:(%-?%d+):(%-?%d+):(%-?%d+):(%-?%d+)")
  if first then  -- Check if the string pattern matching succeeded.
    local satellite = worldId:match(":(%-?%d+)", last)  -- tonumber returns nil if satellite is nil.
    return {
      location = {tonumber(x), tonumber(y), tonumber(z)},
      planet = tonumber(planet),
      satellite = tonumber(satellite)
    }
  end
end

---Populates `affectedTiles` with a list of tiles that are exposed to the surface below given a central position `pos`.
---@param pos Vec2I
---@param affectedTiles table<string, boolean>
---@return HeightMap
function surfaceTileQuery(pos, affectedTiles)
  local heightMap = vMinistar.HeightMap:new()

  local lowestSectors = findLowestLoadedSectors(checkMinX + pos[1], checkMaxX + pos[1], pos[2])

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
  for i = checkMinX, checkMaxX do
    local x = i + pos[1]
    -- Find associated lowest sector.
    local xSector = x // SECTOR_SIZE
    local sectorValue = lowestSectorsMap[xSector]
    local cappedCheckMinY = sectorValue.y
    local checkMinYWasCapped = sectorValue.capped

    -- Proceed only if cappedCheckMinY is not actually capped or there is a liquid with ID sunLiquidId at the position
    -- directly below cappedCheckMinY.
    local shouldProceed = not checkMinYWasCapped
    if checkMinYWasCapped then
      local liquid = world.liquidAt({x, cappedCheckMinY - 1})
      if liquid and liquid[1] == sunLiquidId then
        shouldProceed = true
      end
    end

    if shouldProceed then
      local collidePoints = world.collisionBlocksAlongLine({x, cappedCheckMinY}, {x, checkMaxY + pos[2]}, collisionSet, maxPenetration)

      -- Mark all tiles as affected. Stop after reaching the first solid, opaque tile.
      local foundSolidTile = false
      for _, collideTile in ipairs(collidePoints) do
        local material = world.material(collideTile, "foreground")
        if material then
          local collideTileStr = vVec2.iToString(collideTile)
          affectedTiles[collideTileStr] = true
          local matCfg = getMaterialConfig(material)
          if matCfg and not matCfg.renderParameters.lightTransparent and matCfg.collisionKind == "solid" then
            -- Add to height map.
            -- heightMap.list[i - checkMinX + 1] = collideTile[2]
            heightMap:set(x, collideTile[2])
            foundSolidTile = true
            break
          end
        end
      end

      -- Manually set the heightMap entry if no solid, opaque tile was found, or collidePoints is empty.
      if not foundSolidTile then
        -- heightMap.list[i - checkMinX + 1] = checkMaxY + pos[2]
        heightMap:set(x, checkMaxY + pos[2])
      end
    else
      -- heightMap.list[i - checkMinX + 1] = cappedCheckMinY
      heightMap:set(x, cappedCheckMinY)
    end
  end

  return heightMap
end

---Syncs the given height map to the global height map.
---@param heightMap HeightMap
function syncHeightMapToGlobal(heightMap)
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

---Applies received entity height maps to the given `heightMap`.
---@param heightMap HeightMap
function applyEntityHeightMaps(heightMap)
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

  -- Merge height map with flattenedEntityHeightMap
  for x, v in heightMap:xvalues() do
    local otherV = flattenedEntityHeightMap:get(x)
    if otherV and otherV < v then
      heightMap:set(x, otherV)
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
---@param dt number
function addToHeatMap(affectedTiles, heightMap, dt)
  -- For each tile in `affectedTiles`...
  for tileHash, _ in pairs(affectedTiles) do
    local tile = vVec2.iFromString(tileHash)
    local material = world.material(tile, "foreground")

    local heightMapValue = heightMap:get(tile[1])
    -- Whether or not the affected tile is exposed (and therefore should be burned). Used to address false positives.
    local isExposed = not heightMapValue or tile[2] <= heightMapValue
    local nextToSunLiquid = isAdjacentToSunLiquid(tile)
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

---Returns whether or not the player is exposed to the sunlight below provided a `heightMap`.
---@param heightMap HeightMap
---@return boolean
function isExposedForeground(heightMap)
  local pos = mcontroller.position()
  local boundBox = rect.translate(mcontroller.boundBox(), pos)
  local y = pos[2]

  -- For each x across the current bounding box...
  for x = boundBox[1], boundBox[3] do
    -- local heightMapItem = heightMap.list[math.floor(x) - heightMap.startXPos + 1]
    local heightMapItem = heightMap:get(math.floor(world.xwrap(x)))

    if minDepth < y and y < heightMapItem then
      return true
    end
  end

  return false
end

---Returns whether or not the given position `pos` is adjacent to a liquid with ID `sunLiquidId`.
---@param pos Vec2I
function isAdjacentToSunLiquid(pos)
  -- For each adjacent tile...
  for _, offset in ipairs(ADJACENT_TILES) do
    local liquid = world.liquidAt(vec2.add(pos, offset))  -- Get the liquid at that position.
    -- If a liquid is present and its ID is `sunLiquidId`...
    if liquid and liquid[1] == sunLiquidId then
      return true
    end
  end

  return false
end

---Returns a list of the lowest sectors loaded between `xStart` and `xEnd`, starting at `yStart`.
---@param xStart number
---@param xEnd number
---@param yStart number
---@return Vec2I[]
function findLowestLoadedSectors(xStart, xEnd, yStart)
  local xSectorStart = xStart // SECTOR_SIZE
  local xSectorEnd = xEnd // SECTOR_SIZE
  local ySectorStart = yStart // SECTOR_SIZE

  local lowestSectors = {}

  -- For each column of sectors intersecting the area between xStart and xEnd...
  for xSector = xSectorStart, xSectorEnd do
    local ySector = ySectorStart
    -- While the current sector is loaded...
    -- while world.material({xSector * SECTOR_SIZE, ySector * SECTOR_SIZE}, "foreground") ~= nil do
    while not world.pointCollision({xSector * SECTOR_SIZE, ySector * SECTOR_SIZE}, {"Null"}) do
      ySector = ySector - 1
    end

    -- Add result to lowestSectors
    table.insert(lowestSectors, {xSector, ySector})
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
      boosts:set(x, boosts:get(x) + normalDistribution(flare.x, flare.spread / 3, x) * flare.potency * timeMultiplier)
    end
  end

  return boosts
end

function normalDistribution(mean, stdDev, x)
  return math.exp(-(x - mean) ^ 2 / (2 * stdDev ^ 2))
end