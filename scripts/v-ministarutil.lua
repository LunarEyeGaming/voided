vMinistar = {}

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