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

local undergroundTileQueryThread

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
  -- Do not run this script on planets that are not of type "v-ministar"
  if world.type() ~= "v-ministar" then
    script.setUpdateDelta(0)
    return
  end

  script.setUpdateDelta(6)

  cfg = root.assetJson("/v-matattributes.config:ministarHeatConfig")
  unmeltableMaterials = {}
  for _, material in ipairs(cfg.unmeltableMaterials) do
    unmeltableMaterials[material] = true
  end

  ---@type HeatedTile[]
  heatMap = {}

  entityHeightMaps = {}

  message.setHandler("v-ministarheat-setEntityCollision", function(_, _, sourceId, heightMap)
    entityHeightMaps[sourceId] = heightMap
  end)

  minBurnDamage = 1
  maxBurnDamage = 20
  tickTime = 0.5

  tickDamage = VTickDamage:new{ kind = "fire", amount = minBurnDamage, damageType = "IgnoresDef", interval = tickTime, source = player.id() }

  checkMinX = -100
  checkMaxX = 100
  checkMinY = -100
  checkMaxY = 100
  maxPenetration = 40  -- Maximum number of transparent blocks to penetrate.

  collisionSet = {"Block", "Platform"}
  sunLiquidId = 218
  materialConfigs = {}

  undergroundTileQueryThread = coroutine.create(undergroundTileQuery)

  celestialParamsFetched = false

  vTime.addInterval(5, function()
    for entityId, _ in pairs(entityHeightMaps) do
      if not world.entityExists(entityId) then
        entityHeightMaps[entityId] = nil
      end
    end
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
    burnDepth = 1500

    message.setHandler("v-ministarheat-getSpawnRange", function()
      return {1400, maxDepth}
    end)

    celestialParamsFetched = true
  end
end

function update(dt)
  vTime.update(dt)

  -- Need to try fetching celestial parameters repeatedly because celestial.visitableParameters returns nil until
  -- shortly after the world is created (as opposed to immediately afterwards).
  if not celestialParamsFetched then
    fetchCelestialParams()
    return
  end

  local pos = vec2.floor(mcontroller.position())
  local affectedTiles = {}  -- hash map

  coroutine.resume(undergroundTileQueryThread, pos, affectedTiles, dt)

  local heightMap = surfaceTileQuery(pos, affectedTiles)

  syncHeightMapToGlobal(heightMap)

  applyEntityHeightMaps(heightMap)

  -- Process existing entries.
  local tilesToDestroy = processHeatMap(affectedTiles, dt)

  local sunProximityRatio = 1 - math.max(0, math.min((pos[2] - minDepth) / (maxDepth - minDepth), 1))
  -- Update heatMap for v-ministareffects.lua
  world.sendEntityMessage(player.id(), "v-ministareffects-updateBlocks", heatMap, heightMap, sunProximityRatio, minDepth)

  addToHeatMap(affectedTiles, heightMap, dt)

  -- Destroy tiles.
  world.damageTiles(tilesToDestroy, "foreground", mcontroller.position(), "blockish", 2 ^ 32 - 1, 0)

  local burnRatio = (1 - (pos[2] - minDepth) / (burnDepth - minDepth)) + computeSolarFlareBoost(pos[1])

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
end

---Returns celestial coordinates for the current world, if it is a celestial world. Returns `nil` otherwise.
---@return CelestialCoordinate?
function getCelestialCoordinates()
  local worldId = player.worldId()
  local first, last, x, y, z, planet = worldId:find("CelestialWorld:(%-?%d+):(%-?%d+):(%-?%d+):(%-?%d+)")
  if first then  -- Other values will be assigned to nil otherwise.
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
  -- Maps horizontal positions relative to startXPos to collision heights.
  local heightMap = {startXPos = checkMinX + pos[1], list = {}, minHeight = minDepth}

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
            heightMap.list[i - checkMinX + 1] = collideTile[2]
            foundSolidTile = true
            break
          end
        end
      end

      -- Manually set the heightMap entry if no solid, opaque tile was found, or collidePoints is empty.
      if not foundSolidTile then
        heightMap.list[i - checkMinX + 1] = checkMaxY + pos[2]
      end
    else
      heightMap.list[i - checkMinX + 1] = cappedCheckMinY
    end
  end

  return heightMap
end

function syncHeightMapToGlobal(heightMap)
  local startXSector = heightMap.startXPos // SECTOR_SIZE
  local endXSector = (heightMap.startXPos + #heightMap.list) // SECTOR_SIZE

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
  for i, v in ipairs(heightMap.list) do
    local x = world.xwrap(i + heightMap.startXPos - 1)

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

      heightMap.list[i] = sharedValue
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

function applyEntityHeightMaps(heightMap)
  local minXPos = math.huge
  for _, entityHeightMap in pairs(entityHeightMaps) do
    if entityHeightMap.startXPos < minXPos then
      minXPos = entityHeightMap.startXPos
    end
  end

  local flattenedEntityHeightMap = vMinistar.HeightMap:new(minXPos)

  for _, entityHeightMap in pairs(entityHeightMaps) do
    local entityHeightMapObj = vMinistar.HeightMap:new(entityHeightMap.startXPos, entityHeightMap.list)
    for x, v in entityHeightMapObj:xvalues() do
      local otherV = flattenedEntityHeightMap:get(x)
      if not otherV or v < otherV then
        flattenedEntityHeightMap:set(x, v)
      end
    end
  end

  for i = 1, #heightMap.list do
    local x = i + heightMap.startXPos - 1
    local v = heightMap.list[i]
    local otherV = flattenedEntityHeightMap:get(x)
    if otherV and otherV < v then
      heightMap.list[i] = otherV
    end
  end
end

---Coroutine function. Fills `affectedTiles` with tiles that are directly adjacent to spaces occupied by the liquid with
---ID `sunLiquidId`.
---@param pos Vec2I
---@param affectedTiles table<string, boolean>
---@param dt number
function undergroundTileQuery(pos, affectedTiles, dt)
  local rollingAffectedTiles = {}  -- Maintained map of affected tiles.

  local updateAffectedTiles = function(affectedTiles)
    -- Update affectedTiles with rollingAffectedTiles.
    for tilePosHash, _ in pairs(rollingAffectedTiles) do
      affectedTiles[tilePosHash] = true
    end
  end
  -- Queries tiles that are next to entries in rollingAffectedTiles that no longer exist.
  local hotTileQuery = function()
    local startTime = os.clock()  -- Record start time.
    -- Store list of additions because adding to rollingAffectedTiles directly while looping over rollingAffectedTiles
    -- is not recommended.
    local rollingAffectedTilesAdditions = {}
    -- For each tile in rollingAffectedTiles...
    for tilePosHash, _ in pairs(rollingAffectedTiles) do
      local tilePos = vVec2.iFromString(tilePosHash)

      if not world.pointTileCollision(tilePos, collisionSet) then
        rollingAffectedTiles[tilePosHash] = nil  -- Clear the entry.

        -- For each adjacent tile...
        for _, offset in ipairs(ADJACENT_TILES) do
          local offsetTilePos = vec2.add(tilePos, offset)

          -- If the tile is solid and is adjacent to sun liquid...
          if world.pointTileCollision(offsetTilePos, collisionSet) and isAdjacentToSunLiquid(offsetTilePos) then
            rollingAffectedTilesAdditions[vVec2.iToString(offsetTilePos)] = true  -- Add entry to additions.
          end
        end
      end
    end

    -- Merge additions into rollingAffectedTiles.
    for tilePosHash, _ in pairs(rollingAffectedTilesAdditions) do
      rollingAffectedTiles[tilePosHash] = true
    end

    -- Halt for one tick if too much time has passed.
    if os.clock() - startTime > dt * 0.0001 then
      updateAffectedTiles(affectedTiles)
      pos, affectedTiles, dt = coroutine.yield()  -- Halt for the current frame and update the arguments.
      cappedCheckMaxY = math.min(checkMaxY + pos[2], minDepth) -- Update cappedCheckMinY
    end
  end

  -- Repeat indefinitely.
  while true do
    local cappedCheckMaxY = math.min(checkMaxY + pos[2], minDepth)

    -- For each horizontal strip...
    for x = checkMinX, checkMaxX do
      hotTileQuery()
      local startTime = os.clock()  -- Record start time.
      local absX = x + pos[1]  -- Get x in world coordinates.
      -- For each vertical position...
      for y = checkMinY + pos[2], cappedCheckMaxY do
        local tilePos = {absX, y}
        -- If there is a tile and it is adjacent to sun liquid, then set the corresponding entry to true. Otherwise,
        -- delete it.
        rollingAffectedTiles[vVec2.iToString(tilePos)] =
          (world.pointTileCollision(tilePos, collisionSet) and isAdjacentToSunLiquid(tilePos)) or nil
      end
      -- If the time elapsed exceeds dt * 0.0000001...
      if os.clock() - startTime > dt * 0.001 then
        updateAffectedTiles(affectedTiles)
        pos, affectedTiles, dt = coroutine.yield()  -- Halt for the current frame and update the arguments.
        cappedCheckMaxY = math.min(checkMaxY + pos[2], minDepth) -- Update cappedCheckMinY
      end
    end

    updateAffectedTiles(affectedTiles)
    pos, affectedTiles, dt = coroutine.yield()  -- Update the arguments
  end
end

---Given a hash set of `affectedTiles`, updates `heatMap`. Each entry in `heatMap` that is also present in
---`affectedTiles` has its heat increased (decreased otherwise). Returns a list of tiles to destroy. Note: This also
---updates `affectedTiles` to exclude what was found in `heatMap`.
---@param affectedTiles table<string, boolean>
---@param dt number
---@return Vec2I[]
function processHeatMap(affectedTiles, dt)
  local tilesToDestroy = {}
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
        table.remove(heatMap, i)
      end

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

  return tilesToDestroy
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

    local heightMapValue = heightMap.list[tile[1] - heightMap.startXPos + 1]
    local isExposed = not heightMapValue or tile[2] <= heightMapValue  -- Whether or not the affected tile is exposed (and therefore should be burned).

    -- If there is a material at this tile and it is exposed...
    if material and isExposed then
      -- Compute tolerance multiplier (tiles that are closer to minDepth have a lower heat tolerance). Capped at 0.
      local toleranceMultiplier = math.max(0, (tile[2] - minDepth) / (maxDepth - minDepth))

      -- If the tolerance multiplier is at most 1 and the tile is not unmeltable...
      if not unmeltableMaterials[material] and toleranceMultiplier <= 1.0 then
        local matCfg = getMaterialConfig(material)
        local tileConfig = cfg.tileConfigs[material]
        local toleranceOffset = 0
        if tileConfig and tileConfig.toleranceOffset then
          toleranceOffset = tileConfig.toleranceOffset
        end
        local baseTolerance
        if matCfg then
          baseTolerance = matCfg.falling and cfg.fallingTileDefaultTolerance or cfg.defaultTolerance
        else
          baseTolerance = cfg.defaultTolerance
        end
        local tolerance = baseTolerance * toleranceMultiplier + toleranceOffset
        table.insert(heatMap, {pos = tile, heat = 0, heatTolerance = tolerance > dt and tolerance or 0, heatDeltaDir = 1})
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
    local heightMapItem = heightMap.list[math.floor(x) - heightMap.startXPos + 1]

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
        collisionKind = matConfig.collisionKind or "solid"
      }
    end
  end

  return materialConfigs[material]
end

function computeSolarFlareBoost(x)
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

  local boost = 0
  for _, flare in ipairs(solarFlares) do
    local durationStdDev = flare.duration / 6
    local durationMean = flare.startTime + flare.duration / 2
    boost = boost + normalDistribution(flare.x, flare.spread / 3, x) * flare.potency * normalDistribution(durationMean, durationStdDev, world.time())
  end

  return boost
end

function normalDistribution(mean, stdDev, x)
  return math.exp(-(x - mean) ^ 2 / (2 * stdDev ^ 2))
end