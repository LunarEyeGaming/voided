vMinistar = {}

---The size of each sector.
vMinistar.SECTOR_SIZE = 32

---@class VXMap
---@field startXPos integer First wrapped x coordinate that contains a value
---@field endXPos integer Last wrapped x coordinate that contains a value
---@field list table<integer, any>
vMinistar.XMap = {}

---Returns a new instance of a x-map. `startXPos` and `endXPos` can optionally be provided to pre-set the
---boundaries of the x-map.
---@param startXPos integer?
---@param endXPos integer?
---@return VXMap
function vMinistar.XMap:new(startXPos, endXPos)
  if startXPos then
    startXPos = world.xwrap(startXPos)
  end
  if endXPos then
    endXPos = world.xwrap(endXPos)
  end

  local instance = {
    startXPos = startXPos,
    endXPos = endXPos,
    list = {}
  }
  setmetatable(instance, self)
  self.__index = self

  return instance
end

---Creates a x-map from a table.
---@param json table
---@return VXMap
function vMinistar.XMap:fromJson(json)
  local list = {}

  local instance = vMinistar.XMap:new()

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

---Returns the x-map value at `x`, or `nil` if not defined.
---@param x integer
---@return any
function vMinistar.XMap:get(x)
  return self.list[world.xwrap(x)]
end

---Sets the x-map value at `x` to `v`.
---@param x integer
---@param v any
function vMinistar.XMap:set(x, v)
  x = world.xwrap(x)

  -- Update boundaries. Use world.nearestTo to account for world wrapping
  if not self.startXPos then
    self.startXPos = x
    self.endXPos = x
  else
    local startX = world.nearestTo(x, self.startXPos)
    local endX = world.nearestTo(x, self.endXPos)

    if startX == endX then
      if x > endX then
        self.endXPos = x
      else
        self.startXPos = x
      end
    else
      if not (startX <= x and x <= endX) then
        -- If the start is the closer boundary, then assign x to be it. Otherwise, assign x to be the end.
        if math.abs(x - startX) < math.abs(x - endX) then
          self.startXPos = x
        else
          self.endXPos = x
        end
      end
    end
  end
  -- sb.logInfo("%s -> %s: %s", tostring(x), tostring(x - self.startXPos + 1), v)
  self.list[x] = v
end

---Iterates through the x values within the x-map's `xbounds()`, even `nil` values.
---
---Defining new x values in the x-map while using this method will not affect its traversal.
function vMinistar.XMap:xvalues()
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
function vMinistar.XMap:values()
  return pairs(self.list)
end

---Returns the boundaries of the x-map for easy iteration.
---@return integer
---@return integer
function vMinistar.XMap:xbounds()
  local startX = self.startXPos
  local endX = self.endXPos
  if startX > endX then
    endX = endX + world.size()[1]
  end
  return startX, endX
end

---Returns a combined x-map containing the contents of all of the given x-maps. If any x-maps overlap in entries, maps
---listed later will take a higher priority.
---@param maps VXMap[]
---@return VXMap
function vMinistar.XMap:merge(maps)
  local merged = vMinistar.XMap:new()
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

    mergedStartXPos, mergedEndXPos = vMinistar.XMap:_expandBounds(startX, mergedStartXPos, mergedEndXPos)
    mergedStartXPos, mergedEndXPos = vMinistar.XMap:_expandBounds(endX, mergedStartXPos, mergedEndXPos)
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
function vMinistar.XMap:_expandBounds(x, startXPos, endXPos)
  local startX = world.nearestTo(x, startXPos)
  local endX = world.nearestTo(x, endXPos)
  if startX == endX then
    if x > endX then
      endXPos = x
    else
      startXPos = x
    end
  else
    if not (startX <= x and x <= endX) then
      -- If the start is the closer boundary, then assign x to be it. Otherwise, assign x to be the end.
      if math.abs(x - startX) < math.abs(x - endX) then
        startXPos = x
      else
        endXPos = x
      end
    end
  end

  return startXPos, endXPos
end

---Returns a slice of the given x-map. If the provided boundaries go outside of the defined values of the current
---x-map, then the corresponding values in the slice will be `nil`.
---@param startX integer
---@param endX integer
---@return VXMap
function vMinistar.XMap:slice(startX, endX)
  local sliced = vMinistar.XMap:new()

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

  sliced.startXPos = startX
  sliced.endXPos = endX

  return sliced
end

---Draws debug text for the current XMap.
---@param y number
---@param peakY integer
---@param color Color
---@param displayX boolean?
function vMinistar.XMap:debug(y, peakY, color, displayX)
  if displayX then
    for x, v in self:values() do
      world.debugText("%s: %s", x, v, {x, y + x % peakY}, color)
    end
  else
    for x, v in self:values() do
      world.debugText("%s", v, {x, y + x % peakY}, color)
    end
  end
end

---Sets the appropriate sectors of the globalHeightMap world property to contain the values in heightMap.
---@param heightMap VXMap
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
    -- Get global x-map section corresponding to `xSector`.
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

---Returns an XMap containing boost values for each x value from `startX` to `endX`.
---@param startX integer
---@param endX integer
---@return VXMap
function vMinistar.computeSolarFlareBoosts(startX, endX)
  local function normalDistribution(mean, stdDev, x)
    return math.exp(-(x - mean) ^ 2 / (2 * stdDev ^ 2))
  end

  ---Returns whether or not `x` is inside of a no-flare zone (with the no-flare zones given by `noFlareZones`).
  ---@param x integer
  ---@param noFlareZones {startX: integer, endX: integer}[]
  ---@return boolean
  local function inNoFlareZone(x, noFlareZones)
    for _, zone in ipairs(noFlareZones) do
      if zone.startX <= x and x <= zone.endX then
        return true
      end
    end

    return false
  end

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

  sb.setLogMap("v-ministarheat(stagehand)_solarFlares", "%s", #solarFlares)

  local world_xwrap = world.xwrap

  local boosts = vMinistar.XMap:new(startX, endX)
  local boosts_list = boosts.list
  for x = startX, endX do
    boosts_list[world_xwrap(x)] = 0
  end

  for _, flare in ipairs(solarFlares) do
    -- Dividing by 6 makes it so that all points within the duration are within 3 standard deviations of the mean in either direction.
    local durationStdDev = flare.duration / 6
    local durationMean = flare.startTime + flare.duration / 2
    local timeMultiplier = normalDistribution(durationMean, durationStdDev, world.time())
    local invSpread = 1 / flare.spread
    local flareX = flare.x
    local potency = flare.potency

    for x = startX, endX do
      if not inNoFlareZone(x, noFlareZones) then
        local xWrapped = world_xwrap(x)
        boosts_list[xWrapped] = boosts_list[xWrapped] + math.abs(x - flareX) * invSpread * potency
          * timeMultiplier
      end
    end
  end

  return boosts
end

---Retrieves a section of the global height map and returns it.
---@param startX integer
---@param endX integer
---@param default integer? Default value to use for undefined sections of the height map.
---@return VXMap
function vMinistar.getHeightMap(startX, endX, default)
  local SECTOR_SIZE = vMinistar.SECTOR_SIZE
  local startXSector = startX // SECTOR_SIZE
  local endXSector = endX // SECTOR_SIZE

  local heightMap = vMinistar.XMap:new(startX, endX)
  local heightMap_list = heightMap.list
  for x = startX, endX do
    heightMap_list[world.xwrap(x)] = default
  end

  -- For each `xSector` from `startXSector` to `endXSector`...
  for xSector = startXSector, endXSector do
    local xSectorWrapped = math.floor(world.xwrap(xSector * SECTOR_SIZE) // SECTOR_SIZE)
    -- Get global height map section corresponding to `xSector`.
    local globalHeightMapSection = world.getProperty("v-globalHeightMap." .. xSectorWrapped) or {}

    -- Copy the section over to heightMap.
    for _, value in ipairs(globalHeightMapSection) do
      if math.floor(startX) <= value.x and value.x <= math.floor(endX) then
        heightMap_list[world.xwrap(value.x)] = value.value
      end
    end
  end

  return heightMap
end