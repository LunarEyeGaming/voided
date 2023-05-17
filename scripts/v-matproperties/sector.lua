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

local SECTOR_SIZE = 32

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
      local matMods = _searchTile(getPosFromSector(sector, {x, y}), matModsToQuery)

      -- Push MatMods into results
      for _, matModObject in ipairs(matMods) do
        table.insert(results, matModObject)
      end
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
  Returns the sector that the current position occupies.
  
  param pos: the position to use
  returns: the sector corresponding to the given position
]]
function getSector(pos)
  return {pos[1] // SECTOR_SIZE, pos[2] // SECTOR_SIZE}
end

--[[
  Helper function. Searches a single tile in both layers for mat mods. Returns a list of MatMods. At most two can be 
  returned as a mat mod can occupy at most two layers.
  
  param pos: the position to search through
  param matModsToQuery: (optional) a list containing the mat mods to find
  returns: a list of MatMods, with at most two entries
]]
function _searchTile(pos, matModsToQuery)
  local results = {}
  -- If searchTileInLayer() returns nil in either call, the respective line will have no effect.
  table.insert(results, _searchTileInLayer(pos, "foreground", matModsToQuery))
  table.insert(results, _searchTileInLayer(pos, "background", matModsToQuery))
  
  return results
end

--[[
  Helper function. Searches a single tile in one layer for a matmod. Returns a single MatMod, or nil if no matmod within
  the matModsToQuery is present. If matModsToQuery is not specified, 
  
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