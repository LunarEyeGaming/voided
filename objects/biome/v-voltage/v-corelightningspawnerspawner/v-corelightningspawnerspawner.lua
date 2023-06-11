require "/scripts/util.lua"
require "/scripts/vec2.lua"

local spawnerType
local loaderType

local loaderGapHeight
local loaderMaxSpawnHeight

function init()
  spawnerType = "v-corelightningspawner"
  loaderType = "v-chunkloader"
  loaderGapHeight = 50
  loaderMaxSpawnHeight = 200

  local oceanLevel = world.oceanLevel(object.position())
  
  -- If an ocean level is given...
  if oceanLevel ~= 0 then
    local spawnPos = {object.position()[1], oceanLevel}
    -- Check if a stagehand of the specified type exists at the given ocean level (to avoid spawning multiple).
    local queried = world.entityQuery(spawnPos, 1, {includedTypes = {"stagehand"}})
    queried = util.filter(queried, function(entityId) return world.stagehandType(entityId) == spawnerType end)
    
    -- If not...
    if #queried == 0 then
      spawnStagehands(spawnPos)
    end
  end
  
  object.smash(true)
end

-- Spawns the stagehands that spawns core lightning as well as the chunk loaders.
function spawnStagehands(startPos)
  -- Spawn lightning spawner
  world.spawnStagehand(startPos, spawnerType)
  
  -- Spawn chunk loaders.
  for y = loaderGapHeight, loaderMaxSpawnHeight, loaderGapHeight do
    world.spawnStagehand(vec2.add(startPos, {0, y}), loaderType, {loadPosition = startPos})
  end
end