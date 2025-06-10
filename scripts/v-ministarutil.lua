vMinistar = {}

-- TODO: Figure out how to handle world wrapping in this class.

---The size of each sector.
vMinistar.SECTOR_SIZE = 32

---@class HeightMap
---@field startXPos integer
---@field list table<integer, integer>
---@field endXPos integer
vMinistar.HeightMap = {}

---Returns a new instance of a height map.
---@param startXPos integer
---@param list? table<integer, integer>
---@return HeightMap
function vMinistar.HeightMap:new(startXPos, list)
  list = list or {}
  local instance = {
    startXPos = startXPos,
    list = list,
    endXPos = startXPos + #list
  }
  setmetatable(instance, self)
  self.__index = self

  return instance
end

---Returns the height map value at `x`, or `nil` if not defined.
---@param x integer
---@return integer?
function vMinistar.HeightMap:get(x)
  return self.list[x - self.startXPos + 1]
end

---Returns the index as well as the height map value at `x`, or `nil` if not defined.
---@param x integer
---@return integer, integer?
function vMinistar.HeightMap:geti(x)
  local i = x - self.startXPos + 1
  return i, self.list[i]
end

---Sets the height map value at `x` to `v`.
---
---Performance note: setting a value at `x` if `x < self.startXPos` will shift all current entries to the right.
---@param x integer
---@param v integer
function vMinistar.HeightMap:set(x, v)
  if x < self.startXPos then  -- TODO: Test
    table.move(self.list, 1, self.endXPos - self.startXPos + 1, self.startXPos - x + 1)
    self.startXPos = x
  elseif x > self.endXPos then
    self.endXPos = x
  end
  -- sb.logInfo("%s -> %s: %s", tostring(x), tostring(x - self.startXPos + 1), v)
  self.list[x - self.startXPos + 1] = v
end

---Contiguous height map iterator.
---
---Adding new values to height map while iterating will not change how far it iterates.
function vMinistar.HeightMap:xvalues()
  local i = 0
  return function()
    i = i + 1
    local v = self.list[i]
    if v ~= nil then
      return i + self.startXPos - 1, v
    end
  end
end

---Non-contiguous height map iterator
function vMinistar.HeightMap:values()
  local idx = nil
  return function()
    idx, v = next(self.list, idx)
    if idx then
      return idx + self.startXPos - 1, v
    end
  end
end

---@class VLiquidScanner
---@field _checkMinX integer
---@field _checkMaxX integer
---@field _checkMinY integer
---@field _checkMaxY integer
---@field _liquidId LiquidId
---@field _liquidThreshold number
---@field _CHUNK_SIZE integer
---@field _hotRegions table
---@field _prevLiquidChunks table
vMinistar.LiquidScanner = {}

---Instantiates a new liquid scanner.
---@param args table
---@return VLiquidScanner
function vMinistar.LiquidScanner:new(args)
  local instance = {
    _checkMinX = args.checkMinX,
    _checkMaxX = args.checkMaxX,
    _checkMinY = args.checkMinY,
    _checkMaxY = args.checkMaxY,
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

---Attempts to runs a query at position `pos`, returning the tiles that are adjacent to liquid sun and a list of
---particle spawn points for each chunk that was queried. Should be called every tick.
---
---@param pos Vec2I
---@return Vec2I[], table<string, Vec2I[]>
function vMinistar.LiquidScanner:update(pos)
  local CHUNK_SIZE = self._CHUNK_SIZE
  local liquidId = self._liquidId
  local chunkMinX = (self._checkMinX + pos[1]) // CHUNK_SIZE
  local chunkMinY = (self._checkMinY + pos[2]) // CHUNK_SIZE
  local chunkMaxX = (self._checkMaxX + pos[1]) // CHUNK_SIZE
  local chunkMaxY = (self._checkMaxY + pos[2]) // CHUNK_SIZE
  local boundaryTiles = {}
  local liquidChunks = {}  -- Map of chunks to corresponding liquid values retrieved from world.liquidAt
  local particleSpawnPoints = {}  -- Map of chunks to lists of particle spawn points.

  for chunkX = chunkMinX, chunkMaxX do
    for chunkY = chunkMinY, chunkMaxY do
      local res = world.liquidAt({
        chunkX * CHUNK_SIZE,
        chunkY * CHUNK_SIZE,
        (chunkX + 1) * CHUNK_SIZE,
        (chunkY + 1) * CHUNK_SIZE
      })

      local chunkStr = vVec2.iToString({chunkX, chunkY})

      liquidChunks[chunkStr] = res

      if not particleSpawnPoints[chunkStr] then
        particleSpawnPoints[chunkStr] = {}
      end

      -- Process the region in more detail if it is not completely filled with sun liquid.
      if res and res[1] == liquidId and res[2] < 1.0 then
        local prevRes = self._prevLiquidChunks[chunkStr]
        if self._hotRegions[chunkStr] and self._hotRegions[chunkStr] > 0
            or (not prevRes or prevRes[1] ~= res[1] or math.abs(prevRes[2] - res[2]) * CHUNK_SIZE * CHUNK_SIZE >= 1) then
          local minXInChunk = chunkX * CHUNK_SIZE
          local minYInChunk = chunkY * CHUNK_SIZE
          local maxXInChunk = (chunkX + 1) * CHUNK_SIZE
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
            local liqs = world.liquidAlongLine({x, minYInChunk - 1}, {x, maxYInChunk + 1})

            for _, posLiquidPair in ipairs(liqs) do
              local position = posLiquidPair[1]
              local liquid = posLiquidPair[2]
              liqMat[position[2]][position[1]] = liquid[1] == liquidId and liquid[2] >= self._liquidThreshold
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
                  table.insert(boundaryTiles, {x + 1, y})
                end
                if not row[x - 1] then
                  table.insert(boundaryTiles, {x - 1, y})
                end
                if not liqMat[y + 1][x] then
                  table.insert(boundaryTiles, {x, y + 1})
                  table.insert(particleSpawnPoints[chunkStr], {x, y + 1})
                end
                if not liqMat[y - 1][x] then
                  table.insert(boundaryTiles, {x, y - 1})
                end
              end
            end
          end
          -- Decrement hot region time remaining.
          if self._hotRegions[chunkStr] then
            self._hotRegions[chunkStr] = self._hotRegions[chunkStr] - 1
          end
        end

      else
        table.insert(particleSpawnPoints[chunkStr], {0, 0})
      --   world.debugPoly({
      --     {chunkX * LIQUID_QUERY_CHUNK_SIZE, chunkY * LIQUID_QUERY_CHUNK_SIZE},
      --     {chunkX * LIQUID_QUERY_CHUNK_SIZE, (chunkY + 1) * LIQUID_QUERY_CHUNK_SIZE},
      --     {(chunkX + 1) * LIQUID_QUERY_CHUNK_SIZE, (chunkY + 1) * LIQUID_QUERY_CHUNK_SIZE},
      --     {(chunkX + 1) * LIQUID_QUERY_CHUNK_SIZE, chunkY * LIQUID_QUERY_CHUNK_SIZE}
      --   }, "red")
      end
    end
  end

  self._prevLiquidChunks = liquidChunks

  return boundaryTiles, particleSpawnPoints
end

---Refreshes the entire nearby area, forcing the liquid scanner to requery it all next update.
---@param pos Vec2I
function vMinistar.LiquidScanner:refresh(pos)
  local chunkMinX = (self._checkMinX + pos[1]) // self._CHUNK_SIZE
  local chunkMinY = (self._checkMinY + pos[2]) // self._CHUNK_SIZE
  local chunkMaxX = (self._checkMaxX + pos[1]) // self._CHUNK_SIZE
  local chunkMaxY = (self._checkMaxY + pos[2]) // self._CHUNK_SIZE

  for chunkX = chunkMinX, chunkMaxX do
    for chunkY = chunkMinY, chunkMaxY do
      local chunkStr = vVec2.iToString({chunkX, chunkY})
      self._hotRegions[chunkStr] = 1
    end
  end
end

---Marks a region as "hot" by the given tile for the given number of ticks.
---@param tile Vec2I
---@param time integer
function vMinistar.LiquidScanner:markRegionByTile(tile, time)
  local tileChunkStr = vVec2.iToString({tile[1] // self._CHUNK_SIZE, tile[2] // self._CHUNK_SIZE})
  self._hotRegions[tileChunkStr] = time
end

function vMinistar.setGlobalHeightMap(heightMap)
  local startXSector = heightMap.startXPos // vMinistar.SECTOR_SIZE
  local endXSector = (heightMap.startXPos + #heightMap.list) // vMinistar.SECTOR_SIZE

  -- Map from horizontal positions to `HeightMapItem`.
  ---@type table<integer, HeightMapItem>
  local globalHeightMap = {}
  -- For each `xSector` from `startXSector` to `endXSector`...
  for xSector = startXSector, endXSector do
    local xSectorWrapped = math.floor(world.xwrap(xSector * vMinistar.SECTOR_SIZE) // vMinistar.SECTOR_SIZE)
    -- Get global height map section corresponding to `xSector`.
    local globalHeightMapSection = world.getProperty("v-globalHeightMap." .. xSectorWrapped) or {}

    -- Copy the section over to globalHeightMap.
    for _, value in ipairs(globalHeightMapSection) do
      globalHeightMap[value.x] = value.value
    end
  end

  -- For each entry in the list of `heightMap`...
  for i, v in ipairs(heightMap.list) do
    local x = math.floor(world.xwrap(i + heightMap.startXPos - 1))

    globalHeightMap[x] = v
  end

  -- Store globalHeightMap sections.
  -- For each `xSector` from `startXSector` to `endXSector`...
  for xSector = startXSector, endXSector do
    local globalHeightMapSection = {}
    local xSectorWrapped = math.floor(world.xwrap(xSector * vMinistar.SECTOR_SIZE) // vMinistar.SECTOR_SIZE)

    -- For each x value in the sector...
    for x = xSectorWrapped * vMinistar.SECTOR_SIZE, (xSectorWrapped + 1) * vMinistar.SECTOR_SIZE - 1 do
      -- Add to the section.
      table.insert(globalHeightMapSection, {x = math.floor(x), value = globalHeightMap[math.floor(x)]})
    end

    world.setProperty("v-globalHeightMap." .. xSectorWrapped, globalHeightMapSection)
  end
end