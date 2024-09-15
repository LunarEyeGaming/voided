require "/scripts/vec2.lua"
require "/scripts/util.lua"

--[[
  Contains some scripts for using and retrieving sectors from positions. This is used solely for the main.lua module.
]]

--[[
  A MatMod is defined as a table with the following schema:
  {
    String name: The name of the mat mod,
    Vec2I pos: The position of the mat mod,
    String layer: The layer that the mat mod occupies. Either "foreground" or "background"
  }

  A Sector is defined as a Vec2I that gives the coordinates of a position in sectors (a sector is a 32x32 region of
  tiles).
]]

SECTOR_SIZE = 32

--[[
  Queries a single sector of a list of mat mods (or all existing mat mods if not specified) and returns their positions
  and layers.

  param sector: the Sector to query
  param matModsToQuery: (optional) a list containing the mat mods to find
  returns: a list of MatMods within the sector that are in the matModsToQuery
]]
function querySector(sector, matModsToQuery)
  local results = {}

  for x = 0, SECTOR_SIZE do
    for y = 0, SECTOR_SIZE do
      -- local matMods = _searchTile(getPosFromSector(sector, {x, y}), matModsToQuery)

      -- -- Push MatMods into results
      -- for _, matModObject in ipairs(matMods) do
      --   table.insert(results, matModObject)
      -- end

      -- Calculate absolute position. This is an inlined version of getPosFromSector.
      local pos = {sector[1] * SECTOR_SIZE + x, sector[2] * SECTOR_SIZE + y}
      -- If searchTileInLayer() returns nil in either call, the respective line will have no effect.
      table.insert(results, _searchTileInLayer(pos, "foreground", matModsToQuery))
      table.insert(results, _searchTileInLayer(pos, "background", matModsToQuery))
    end
  end

  return results
end

--[[
  Returns true if the given sector is not loaded and false otherwise.

  param sector: the Sector to check
  returns: true if that sector is loaded and false otherwise
]]
function isLoaded(sector)
  local pos = vec2.mul(sector, SECTOR_SIZE)  -- Get the bottom-left corner of the sector

  return world.material(pos, "foreground") ~= nil  -- true if a tile in the current sector is not Null
end

--[[
  Returns the absolute position from a Sector and a given relative position, or the vector sum of the bottom-left corner
  of the given sector and the relative position.

  param sector: the Sector to use
  param relativePos: the relative position to use
  returns: the absolute position from a Sector and a given relative position.
]]
function getPosFromSector(sector, relativePos)
  return {sector[1] * SECTOR_SIZE + relativePos[1], sector[2] * SECTOR_SIZE + relativePos[2]}
  -- return vec2.add(vec2.mul(sector, SECTOR_SIZE), relativePos)
end

--[[
  Returns the Sector that the current position occupies.

  param pos: the position to use
  returns: the Sector corresponding to the given position
]]
function getSector(pos)
  return {pos[1] // SECTOR_SIZE, pos[2] // SECTOR_SIZE}
end

--[[
  Returns the Sectors that the given region occupies.

  param region: the Rect region to use (absolute)
  returns: the Sectors intersecting with the region
]]
function getSectorsInRegion(region)
  local sectors = {}

  -- For each x value from the start to the end, increasing by SECTOR_SIZE each time...
  for x = region[1], region[3], SECTOR_SIZE do
    -- For each y value from the start to the end, increasing by SECTOR_SIZE each time...
    for y = region[2], region[4], SECTOR_SIZE do
      -- Insert sector
      table.insert(sectors, getSector({x, y}))
    end
  end

  -- I have no idea what I'm doing here. Good luck figuring it out :).
  local hasMissedTop = (region[4] - region[2]) // SECTOR_SIZE + region[2] // SECTOR_SIZE ~= region[4] // SECTOR_SIZE
  local hasMissedRight = (region[3] - region[1]) // SECTOR_SIZE + region[1] // SECTOR_SIZE ~= region[3] // SECTOR_SIZE

  -- Edge case at the top
  if hasMissedTop then
    for x = region[1], region[3], SECTOR_SIZE do
      table.insert(sectors, getSector({x, region[4]}))
    end
  end

  -- Edge case at the right
  if hasMissedRight then
    for y = region[2], region[4], SECTOR_SIZE do
      table.insert(sectors, getSector({region[3], y}))
    end
  end

  -- Corner case
  if hasMissedTop and hasMissedRight then
    table.insert(sectors, getSector({region[3], region[4]}))
  end

  return sectors
end

-- --[[
--   Helper function. Searches a single tile in both layers for mat mods. Returns a list of MatMods. At most two can be
--   returned as a mat mod can occupy at most two layers.

--   param pos: the position to search through
--   param matModsToQuery: (optional) a list containing the mat mods to find
--   returns: a list of MatMods, with at most two entries
-- ]]
-- function _searchTile(pos, matModsToQuery)
--   local results = {}
--   -- If searchTileInLayer() returns nil in either call, the respective line will have no effect.
--   table.insert(results, _searchTileInLayer(pos, "foreground", matModsToQuery))
--   table.insert(results, _searchTileInLayer(pos, "background", matModsToQuery))

--   return results
-- end

-- --[[
--   Helper function. Searches a single tile in one layer for a matmod. Returns a single MatMod, or nil if no matmod within
--   the matModsToQuery is present. If matModsToQuery is not specified, then a MatMod is returned if one exists.

--   param pos: the position to search through
--   param layer: the layer to search in. It is up to the programmer to make sure this value is valid
--   param matModsToQuery: (optional) a list containing the mat mods to find
--   returns: a MatMod, or nil if no matmod is present.
-- ]]
-- function _searchTileInLayer(pos, layer, matModsToQuery)
--   local matMod = world.mod(pos, layer)
--   -- local matMod = nil
--   -- If matMod is not nil and matMod is in the matModsToQuery list (if specified), stop and return a MatMod object.
--   if matMod and (not matModsToQuery or contains(matModsToQuery, matMod)) then
--     return {name = matMod, pos = pos, layer = layer}
--   end

--   return nil
-- end

--[[
  Helper function. Searches a single tile in one layer for a matmod. Returns a single MatMod, or nil if no matmod within
  the matModsToQuery is present. If matModsToQuery is not specified, then a MatMod is returned if one exists.

  param pos: the position to search through
  param layer: the layer to search in. It is up to the programmer to make sure this value is valid
  param matModsToQuery: (optional) a list containing the mat mods to find
  returns: a MatMod, or nil if no matmod is present.
]]
function _searchTileInLayer(pos, layer, matModsToQuery)
  local matMod = world.mod(pos, layer)
  -- local matMod = nil
  -- If matMod is not nil and matMod is in the matModsToQuery list (if specified), stop and return a MatMod object.
  if matMod and (not matModsToQuery or contains(matModsToQuery, matMod)) then
    return {name = matMod, pos = pos, layer = layer}
  end

  return nil
end