--[[
  A simple script that replaces the current object with another one depending on the biome blocks.
]]

require "/scripts/v-util.lua"
require "/scripts/util.lua"

function init()
  local blocks = world.biomeBlocksAt(object.position()  --[[@as Vec2I]])

  local newObject = getNewObject(blocks)

  object.smash(true)

  if newObject then
    world.placeObject(newObject, object.position()  --[[@as Vec2I]], object.direction())
  end
end

---Returns the object to place depending on `objectSwapMap` and the given list of `biomeBlocks`, or `nil` if no such
---object is found.
---@param biomeBlocks integer[]
---@return string?
function getNewObject(biomeBlocks)
  -- Get object swap map.
  local objectSwapMap = config.getParameter("objectSwapMap")

  -- Get biome blocks copy.
  local biomeBlocksCopy = copy(biomeBlocks)
  table.sort(biomeBlocksCopy)

  -- For each entry in objectSwapMap...
  for _, entry in ipairs(objectSwapMap) do
    -- Get the numeric ID equivalent of the entry's required biome blocks.
    local requiredBiomeBlocks = util.map(entry.requiredBiomeBlocks, getMaterialId)
    table.sort(requiredBiomeBlocks)

    -- If the required biome blocks match the given biome blocks...
    if voidedUtil.deepEquals(requiredBiomeBlocks, biomeBlocksCopy) then
      return entry.replacement
    end
  end

  return nil
end

---Returns the ID of a material with a given name. Fails if no such material exists.
---@param materialName string
---@return integer
function getMaterialId(materialName)
  local blockConfig = root.materialConfig(materialName)

  -- If no config is found...
  if not blockConfig then
    -- Abort script and report error.
    error("Material with name '".. materialName .."' is a metamaterial or does not exist.")
  end

  return blockConfig.config.materialId
end