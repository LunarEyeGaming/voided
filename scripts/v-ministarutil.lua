vMinistar = {}

---The size of each sector.
vMinistar.SECTOR_SIZE = 32

---@class HeightMap
---@field startXPos integer First wrapped x coordinate that contains a value
---@field endXPos integer Last wrapped x coordinate that contains a value
---@field list table<integer, integer>
vMinistar.HeightMap = {}

---Returns a new instance of a height map.
---@return HeightMap
function vMinistar.HeightMap:new()
  local instance = {
    startXPos = nil,
    endXPos = nil,
    list = {}
  }
  setmetatable(instance, self)
  self.__index = self

  return instance
end

---Creates a height map from a table.
---@param json table
---@return HeightMap
function vMinistar.HeightMap:fromJson(json)
  local list = {}

  local instance = vMinistar.HeightMap:new()

  -- Build the list and a parallel list for sorting. Then, find the biggest gap between two consecutive values in the sorted list.
  for xStr, v in pairs(json.list) do
    local x = tonumber(xStr)
    assert(x ~= nil, "JSON must be an array or an object containing keys representing numbers")

    list[x] = v
  end
  instance.list = list
  instance.startXPos = json.startXPos
  instance.endXPos = json.endXPos

  return instance
end

---Returns the height map value at `x`, or `nil` if not defined.
---@param x integer
---@return integer?
function vMinistar.HeightMap:get(x)
  return self.list[world.xwrap(x)]
end

---Sets the height map value at `x` to `v`.
---@param x integer
---@param v integer
function vMinistar.HeightMap:set(x, v)
  x = world.xwrap(x)

  -- Update boundaries. Use world.nearestTo to account for world wrapping
  if not self.startXPos then
    self.startXPos = x
    self.endXPos = x
  else
    local startX = world.nearestTo(x, self.startXPos)
    local endX = world.nearestTo(x, self.endXPos)

    -- TODO: Handle setting values in descending order. Possible solution: when self.startXPos == self.endXPos, if x > self.endXPos,
    -- set self.endXPos to x. Otherwise, set self.startXPos to x.
    if not (startX <= x and x <= endX) then
      -- If the start is the closer boundary, then assign x to be it. Otherwise, assign x to be the end.
      if math.abs(x - startX) < math.abs(x - endX) then
        self.startXPos = x
      else
        self.endXPos = x
      end
    end
  end

  -- if x < world.nearestTo(x, self.startXPos) and x <= world.nearestTo(x, self.endXPos) then
  --   if x <= world.nearestTo(x, self.endXPos) then
  --     self.startXPos = x

  --   end
  -- elseif x > world.nearestTo(x, self.endXPos) then
  --   self.endXPos = x
  -- end
  -- sb.logInfo("%s -> %s: %s", tostring(x), tostring(x - self.startXPos + 1), v)
  self.list[x] = v
end

---Iterates through the x values within the height map's `xbounds()`, even `nil` values.
---
---Defining new x values in the height map while using this method will not affect its traversal.
function vMinistar.HeightMap:xvalues()
  local startX, endX = self:xbounds()
  local x = startX - 1
  return function()
    x = x + 1
    local xWrapped = world.xwrap(x)
    local v = self.list[xWrapped]
    if x <= endX then
      return xWrapped, v
    end
  end
end

---Equivalent to pairs(self.list)
function vMinistar.HeightMap:values()
  -- local idx = nil
  -- return function()
  --   idx, v = next(self.list, idx)
  --   if idx then
  --     return idx, v
  --   end
  -- end
  return pairs(self.list)
end

---Returns the boundaries of the height map for easy iteration.
---@return integer
---@return integer
function vMinistar.HeightMap:xbounds()
  local startX = self.startXPos
  local endX = self.endXPos
  if startX > endX then
    endX = endX + world.size()[1]
  end
  return startX, endX
end

---Returns a combined height map containing the contents of all of the given height maps.
---@param maps HeightMap[]
---@return HeightMap
function vMinistar.HeightMap:merge(maps)
  -- TODO: Optimize.
  local merged = vMinistar.HeightMap:new()
  local mergedStartXPos, mergedEndXPos
  if #maps > 0 then
    mergedStartXPos, mergedEndXPos = maps[1]:xbounds()
  end

  local xSize = world.size()[1]

  for _, map in ipairs(maps) do
    local startX, endX = map:xbounds()

    if endX >= xSize then
      local preWrapX = xSize - 1
      local postWrapX = 0
      endX = endX - xSize

      table.move(map.list, startX, preWrapX, startX, merged.list)
      table.move(map.list, postWrapX, endX, postWrapX, merged.list)
    else
      table.move(map.list, startX, endX, startX, merged.list)
    end

    mergedStartXPos, mergedEndXPos = vMinistar.HeightMap:expandBounds(startX, mergedStartXPos, mergedEndXPos)
    mergedStartXPos, mergedEndXPos = vMinistar.HeightMap:expandBounds(endX, mergedStartXPos, mergedEndXPos)
    -- for x, v in map:xvalues() do
    --   merged:set(x, v)
    -- end
  end

  return merged
end

---Given a value `x` and boundaries defined by `startXPos` and `endXPos`, returns new values `startXPos2` and `endXPos2`
---such that `startXPos2 <= x <= endPos2`.
---@param x integer
---@param startXPos integer
---@param endXPos integer
---@return integer startXPos2
---@return integer endXPos2
function vMinistar.HeightMap:expandBounds(x, startXPos, endXPos)
  local startX = world.nearestTo(x, startXPos)
  local endX = world.nearestTo(x, endXPos)
  if not (startX <= x and x <= endX) then
    -- If the start is the closer boundary, then assign x to be it. Otherwise, assign x to be the end.
    if math.abs(x - startX) < math.abs(x - endX) then
      startXPos = x
    else
      endXPos = x
    end
  end

  return startXPos, endXPos
end

---Returns a slice of the given height map. If the provided boundaries go outside of the defined values of the current
---height map, then the corresponding values in the slice will be `nil`.
---@param startX integer
---@param endX integer
---@return HeightMap
function vMinistar.HeightMap:slice(startX, endX)
  -- TODO: Optimize
  local sliced = vMinistar.HeightMap:new()

  if startX > endX then
    error("startX must be less than endX")
  end

  local xSize = world.size()[1]

  if endX - startX > xSize then
    error("Slice sizes exceeding world width are not supported")
  end

  if endX >= xSize then
    local preWrapX = xSize - 1
    local postWrapX = 0
    endX = endX - xSize

    table.move(self.list, startX, preWrapX, startX, sliced.list)
    table.move(self.list, postWrapX, endX, postWrapX, sliced.list)
  elseif startX < 0 then
    local preWrapX = xSize - 1
    local postWrapX = 0
    startX = startX + xSize

    table.move(self.list, startX, preWrapX, startX, sliced.list)
    table.move(self.list, postWrapX, endX, postWrapX, sliced.list)
  else
    table.move(self.list, startX, endX, startX, sliced.list)
  end

  -- for x = startX, endX do
  --   sliced:set(x, self.list[world.xwrap(x)])
  -- end

  sliced.startXPos = startX
  sliced.endXPos = endX

  return sliced
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

---Attempts to runs a query in all regions `regions`, returning the tiles that are adjacent to liquid sun and a list of
---particle spawn points for each chunk that was queried. Should be called every tick.
---
---@param regions RectI[]
---@return Vec2I[], table<string, Vec2I[]>
function vMinistar.LiquidScanner:update(regions)
  local CHUNK_SIZE = self._CHUNK_SIZE
  local liquidId = self._liquidId

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
          -- Add one particle spawn point to differentiate from the spawn point being undefined.
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

---Sets the appropriate sectors of the globalHeightMap world property to contain the values in heightMap.
---@param heightMap HeightMap
function vMinistar.setGlobalHeightMap(heightMap)
  local startX, endX = heightMap:xbounds()
  local startXSector = startX // vMinistar.SECTOR_SIZE
  local endXSector = endX // vMinistar.SECTOR_SIZE

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
  -- for i, v in ipairs(heightMap.list) do
  --   local x = math.floor(world.xwrap(i + heightMap.startXPos - 1))

  --   globalHeightMap[x] = v
  -- end
  for x, v in heightMap:xvalues() do
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