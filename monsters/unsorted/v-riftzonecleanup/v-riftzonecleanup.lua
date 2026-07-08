require "/scripts/rect.lua"

require "/scripts/v-vec2.lua"
require "/scripts/v-world.lua"

local INSTANT_BREAK_DAMAGE = 2 ^ 32

local shouldDieVar

function init()

end

function update(dt)
  if world.regionActive(rect.translate({-32, -32, 32, 32}, mcontroller.position())) then
    local blocksToClearFG = config.getParameter("blocksToClearFG", {})
    local blocksToClearBG = config.getParameter("blocksToClearBG", {})
    local oresToClearFG = config.getParameter("oresToClearFG", {})
    local oresToClearBG = config.getParameter("oresToClearBG", {})

    local partitionedBlocksFG = partitionByChunk(blocksToClearFG)
    local partitionedBlocksBG = partitionByChunk(blocksToClearBG)
    local partitionedOresFG = partitionByChunk(oresToClearFG)
    local partitionedOresBG = partitionByChunk(oresToClearBG)

    pushPartitionToWorldProperty("v-riftzone-blocksToRemoveFG", partitionedBlocksFG)
    pushPartitionToWorldProperty("v-riftzone-blocksToRemoveBG", partitionedBlocksBG)
    pushPartitionToWorldProperty("v-riftzone-oresToRemoveFG", partitionedOresFG)
    pushPartitionToWorldProperty("v-riftzone-oresToRemoveBG", partitionedOresBG)

    local riftZoneData = config.getParameter("riftZoneData")
    local riftZones = world.getProperty("v-riftZones") or jarray()
    table.insert(riftZones, riftZoneData)
    world.setProperty("v-riftZones", riftZones)

    shouldDieVar = true
  end
end

---Partitions blocks by chunks.
---@param blocks Vec2F[]
---@return table<string, Vec2F[]>
function partitionByChunk(blocks)
  local partition = {}

  for _, block in ipairs(blocks) do
    local sector = {block[1] // vWorld.SECTOR_SIZE, block[2] // vWorld.SECTOR_SIZE}

    local sectorStr = vVec2.iToString(sector)
    if not partition[sectorStr] then
      partition[sectorStr] = jarray()
    end

    table.insert(partition[sectorStr], block)
  end

  return partition
end

function pushPartitionToWorldProperty(propertyName, partition)
  local prop = world.getProperty(propertyName) or {}
  for sectorStr, blocks in pairs(partition) do
    local propBlocks = prop[sectorStr]
    if not propBlocks then
      propBlocks = jarray()
      prop[sectorStr] = propBlocks
    end
    -- Append contents of blocks to propBlocks
    for _, block in ipairs(blocks) do
      table.insert(propBlocks, block)
    end
  end
  world.setProperty(propertyName, prop)
end

function shouldDie()
  return shouldDieVar
end