require "/scripts/interp.lua"
require "/scripts/vec2.lua"
require "/scripts/rect.lua"

require "/scripts/v-vec2.lua"
require "/scripts/statuseffects/v-tickdamage.lua"

local cfg
local unmeltableMaterials

local heatMap
local maxDepth
local minDepth

local burnDepth
local minBurnDamage
local maxBurnDamage
local tickTime

local tickDamage

local checkMinX
local checkMaxX
local checkMinY
local checkMaxY

local collisionSet
local sunLiquidId
local materialConfigs

local undergroundTileQueryThread

local ADJACENT_TILES = {{1, 0}, {0, 1}, {-1, 0}, {0, -1}}
local SECTOR_SIZE = 32

---@class HeightMap
---@field startXPos integer the starting horizontal position
---@field minHeight integer the minimum height to use
---@field list HeightMapItem[] the list of height map values.

---@class HeightMapItem
---@field type "partiallyObstructed" | "completelyObstructed" | "open"
---@field value integer? defined if type is "completelyObstructed". The y value in world space given.
---@field minValue integer? defined if type is "open". The minimum y value used for scanning.
---@field maxValue integer? defined if type is "open". The maximum y value used for scanning.

---@class HeatedTile
---@field pos Vec2I
---@field heatTolerance number
---@field heat number

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
  maxDepth = 1980  -- Depth that heats up the slowest
  minDepth = 1000  -- Depth that heats up the fastest. Also the depth at which the player takes the most burn damage.
  undergroundDepthThreshold = 800 -- Depth that the player must be at to use the "underground" variants of some variables

  burnDepth = 1500  -- Depth at which the player starts burning
  minBurnDamage = 1
  maxBurnDamage = 20
  tickTime = 0.5

  tickDamage = VTickDamage:new{ kind = "fire", amount = minBurnDamage, damageType = "IgnoresDef", interval = tickTime, source = player.id() }

  checkMinX = -100
  checkMaxX = 100
  checkMinY = -100
  checkMaxY = 100

  collisionSet = {"Block", "Platform"}
  sunLiquidId = 218
  materialConfigs = {}

  undergroundTileQueryThread = coroutine.create(undergroundTileQuery)
end

function update(dt)
  local pos = vec2.floor(mcontroller.position())
  local affectedTiles = {}  -- hash map

  -- if pos[2] <= undergroundDepthThreshold then
  --   return
  -- end
  coroutine.resume(undergroundTileQueryThread, pos, affectedTiles, dt)

  local heightMap = surfaceTileQuery(pos, affectedTiles)

  syncHeightMapToGlobal(heightMap)

  -- Process existing entries.
  local tilesToDestroy = processHeatMap(affectedTiles, dt)

  local sunProximityRatio = 1 - math.max(0, math.min((pos[2] - minDepth) / (maxDepth - minDepth), 1))
  -- Update heatMap for v-ministareffects.lua
  world.sendEntityMessage(player.id(), "v-ministareffects-updateBlocks", heatMap, heightMap, sunProximityRatio)

  addToHeatMap(affectedTiles, heightMap, dt)

  -- Destroy tiles.
  world.damageTiles(tilesToDestroy, "foreground", mcontroller.position(), "blockish", 2 ^ 32 - 1, 0)

  -- If the player should be burned...
  if pos[2] <= burnDepth and isExposedForeground(heightMap) then
    -- Update damage amount. It is a linear interpolation between maxBurnDamage and minBurnDamage, where damage grows as
    -- depth (aka y position) decreases.
    tickDamage.damageRequest.damage = interp.linear((pos[2] - minDepth) / (burnDepth - minDepth), maxBurnDamage, minBurnDamage)
    tickDamage:update(dt)  -- Run the tickDamage object for one tick.
  else
    tickDamage:reset()
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

  -- world.debugText("%s", lowestSectors, vec2.add(mcontroller.position(), {0, -1}), "green")

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
      local collidePointPair = world.lineTileCollisionPoint({x, cappedCheckMinY}, {x, checkMaxY + pos[2]}, collisionSet)
      if collidePointPair then
        local collidePoint = collidePointPair[1]
        -- world.debugText("%s", collidePoint[2], {x, x % 2 == 0 and pos[2] - 5 or pos[2] - 6}, "green")
        world.debugPoint(collidePoint, "green")
        -- Round the tile's position to the nearest integer
        local collideTile = {math.floor(collidePoint[1] + 0.5), math.floor(collidePoint[2] + 0.5)}
        local collideTileStr = vVec2.iToString(collideTile)
        affectedTiles[collideTileStr] = true

        -- Add to height map.
        heightMap.list[i - checkMinX + 1] = {type = "partiallyObstructed", value = collideTile[2]}
      else
        heightMap.list[i - checkMinX + 1] = {type = "open", minValue = cappedCheckMinY, maxValue = checkMaxY + pos[2]}
      end
    else
      heightMap.list[i - checkMinX + 1] = {type = "completelyObstructed"}
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
    -- Get global height map section corresponding to `xSector`.
    local globalHeightMapSection = world.getProperty("v-globalHeightMap." .. xSector) or {}

    -- For each value in the section...
    for _, value in ipairs(globalHeightMapSection) do
      globalHeightMap[value.x] = value.value  -- Add to `globalHeightMap`
    end
  end

  -- local globalHeightMapSerialized = world.getProperty("v-globalHeightMap") or {}

  -- -- Convert to hash map.
  -- ---@type table<integer, HeightMapItem>
  -- local globalHeightMap = {}
  -- for _, value in ipairs(globalHeightMapSerialized) do
  --   globalHeightMap[value.x] = value.value
  -- end

  local startXPosWrapped = world.xwrap(heightMap.startXPos)
  -- For each entry in the list of `heightMap`...
  for i, v in ipairs(heightMap.list) do
    local x = i + startXPosWrapped - 1
    -- If there is no corresponding entry in `globalHeightMap` or the type of `v` is `completelyObstructed`...
    if not globalHeightMap[x] or v.type == "completelyObstructed" then
      globalHeightMap[x] = v
    else  -- Otherwise, `globalHeightMap[x]` is defined and the type of `v` is not `completelyObstructed`.
      local globalV = globalHeightMap[x]
      local sharedValue

      -- If the global value type is `partiallyObstructed`...
      if globalV.type == "partiallyObstructed" then
        local tilePos = {x, globalV.value}
        -- `globalHeightIsValid` is true if the position at `tilePos` is occupied by a block or is not loaded.
        local globalHeightIsValid = world.pointTileCollision(tilePos, {"Null", "Block", "Platform"})

        -- If `globalHeightIsValid` is false...
        if not globalHeightIsValid then
          sharedValue = v
        -- TODO: Factorize cases.
        -- Otherwise, if the local value type is `partiallyObstructed` and its value is less than the global value...
        elseif v.type == "partiallyObstructed" and v.value < globalV.value then
          sharedValue = v
        else
          sharedValue = globalV
        end
      -- Otherwise, if the global value type is `completelyObstructed`...
      elseif globalV.type == "completelyObstructed" then
        local tilePos = {x, minDepth - 1}
        -- `globalHeightIsValid` is true if either the position at `tilePos` is not loaded or it does not have sun
        -- liquid.
        local globalHeightIsValid = world.pointTileCollision(tilePos, {"Null"})
        if not globalHeightIsValid then
          local liquid = world.liquidAt(tilePos)
          globalHeightIsValid = not liquid or liquid[1] ~= sunLiquidId
        end

        -- Use global value if valid, otherwise local value.
        sharedValue = globalHeightIsValid and globalV or v
      else  -- Otherwise, the global value type is `open`
        sharedValue = v  -- Use local value.
      end
      heightMap.list[i] = sharedValue
      globalHeightMap[x] = sharedValue
      --[[
        globalHeightIsValid = world.pointCollision({x, globalHeightMap[x].value})
        case "partiallyObstructed" for local and "partiallyObstructed" for global:
          local and global <-- the min of each other, assuming global is valid. Otherwise, local
        case "partiallyObstructed" for local and "completelyObstructed" for global:
          local and global <-- global, assuming global is valid. Otherwise, local
        case "partiallyObstructed" for local and "open" for global:
          local and global <-- depends on whether local is within global's scan range, in which case local. Otherwise, global
        case "completelyObstructed" for local and "partiallyObstructed" for global:
          local and global <-- local
        case "completelyObstructed" for local and "completelyObstructed" for global:
          local and global <-- local
        case "completelyObstructed" for local and "open" for global:
          local and global <-- local
        case "open" for local and "partiallyObstructed" for global:
          local and global <-- global, assuming global is valid. Otherwise, local
        case "open" for local and "completelyObstructed" for global:
          local and global <-- global, assuming global is valid. Otherwise, local
        case "open" for local and "open" for global:
          local and global <-- local
      ]]
    end
  end

  -- Store globalHeightMap sections.
  -- For each `xSector` from `startXSector` to `endXSector`...
  for xSector = startXSector, endXSector do
    local globalHeightMapSection = {}

    -- For each x value in the sector...
    for x = xSector * SECTOR_SIZE, (xSector + 1) * SECTOR_SIZE - 1 do
      -- Add to the section.
      table.insert(globalHeightMapSection, {x = x, value = globalHeightMap[x]})
    end

    world.setProperty("v-globalHeightMap." .. xSector, globalHeightMapSection)
  end

  -- -- Convert to serialized format
  -- globalHeightMapSerialized = {}
  -- for x, value in pairs(globalHeightMap) do
  --   table.insert(globalHeightMapSerialized, {x = x, value = value})
  -- end

  -- world.setProperty("v-globalHeightMap", globalHeightMapSerialized)
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

      -- If the tile is no longer occupied...
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

    -- If the time elapsed exceeds dt * 0.00001...
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
      if os.clock() - startTime > dt * 0.0001 then
        updateAffectedTiles(affectedTiles)
        pos, affectedTiles, dt = coroutine.yield()  -- Halt for the current frame and update the arguments.
        cappedCheckMaxY = math.min(checkMaxY + pos[2], minDepth) -- Update cappedCheckMinY
      end
      -- pos, affectedTiles, dt = coroutine.yield()  -- Halt for the current frame and update the arguments.
      -- cappedCheckMaxY = math.min(checkMaxY + pos[2], minDepth) -- Update cappedCheckMinY
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
      -- Increase the heat amount.
      tile.heat = tile.heat + dt

      -- If the heat exceeds the tile's tolerance...
      if tile.heat > tile.heatTolerance then
        table.insert(tilesToDestroy, tile.pos)  -- Add to list of tiles to destroy.
        table.remove(heatMap, i)  -- Remove tile from heatMap.
      end

      -- Remove entry from affectedTiles to avoid excess inserts.
      affectedTiles[tilePosHash] = nil
    -- Otherwise, if the tile no longer exists...
    elseif not world.pointTileCollision(tile.pos, collisionSet) then
      table.remove(heatMap, i)
    else
      -- Decrease heat.
      tile.heat = tile.heat - dt

      -- If the heat drops below zero...
      if tile.heat <= 0 then
        table.remove(heatMap, i)  -- Remove tile from heatMap.
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
    local isExposed  -- Whether or not the affected tile is exposed (and therefore should be burned).
    if not heightMapValue or heightMapValue.type == "open" then
      isExposed = true
    elseif heightMapValue.type == "partiallyObstructed" then
      isExposed = tile[2] <= heightMapValue.value
    else
      isExposed = tile[2] <= minDepth
    end

    world.debugPoint(tile, "red")

    -- If there is a material at this tile and it is exposed...
    if material and isExposed then
      -- Compute tolerance multiplier (tiles that are closer to minDepth have a lower heat tolerance). Capped at 0.
      local toleranceMultiplier = math.max(0, (tile[2] - minDepth) / (maxDepth - minDepth))

      -- If the tolerance multiplier is at most 1 and the tile is not unmeltable...
      if not unmeltableMaterials[material] and toleranceMultiplier <= 1.0 then
        -- Register material if it is valid and is not already registered.
        if not materialConfigs[material] then
          local matConfigAndPath = root.materialConfig(material)
          if matConfigAndPath then
            local matConfig = matConfigAndPath.config
            materialConfigs[material] = {
              falling = matConfig.falling
            }
          end
        end
        -- Get base tolerance
        local baseTolerance = materialConfigs[material].falling and cfg.fallingTileDefaultTolerance or cfg.defaultTolerance
        -- Add to heat map.
        local tolerance = baseTolerance * toleranceMultiplier
        table.insert(heatMap, {pos = tile, heat = 0, heatTolerance = tolerance > dt and tolerance or 0})
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

  -- -- Regarding [1][2]: findLowestLoadedSectors will always return exactly one entry in this case. [1] means first entry;
  -- -- [2] means y value of that entry.
  -- local checkMinY = (findLowestLoadedSectors(pos[1], pos[1], y)[1][2] + 1) * SECTOR_SIZE

  -- -- Variant of checkMinY that stops at minDepth; whether or not the value was capped.
  -- local cappedCheckMinY, checkMinYWasCapped
  -- if checkMinY < minDepth then
  --   cappedCheckMinY = minDepth
  --   checkMinYWasCapped = true
  -- else
  --   cappedCheckMinY = checkMinY
  --   checkMinYWasCapped = false
  -- end

  -- For each x across the current bounding box...
  for x = boundBox[1], boundBox[3] do
    -- -- Proceed only if cappedCheckMinY is not actually capped or there is a liquid with ID sunLiquidId at the position
    -- -- directly below cappedCheckMinY.
    -- local shouldProceed = not checkMinYWasCapped
    -- if not shouldProceed then
    --   local liquid = world.liquidAt({x, cappedCheckMinY - 1})
    --   if liquid and liquid[1] == sunLiquidId then
    --     shouldProceed = true
    --   end
    -- end

    -- -- If we should proceed and there is a section beneath the player that is exposed...
    -- if shouldProceed and not world.lineTileCollision({x, y}, {x, cappedCheckMinY}, {"Block"}) then
    --   return true
    -- end

    local heightMapItem = heightMap.list[math.floor(x) - heightMap.startXPos + 1]

    -- If the height map item type is `open` or it is `partiallyObstructed` and its value is greater than y...
    if heightMapItem.type == "open" or heightMapItem.type == "partiallyObstructed" and heightMapItem.value > y then
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