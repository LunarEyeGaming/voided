require "/scripts/util.lua"
require "/scripts/vec2.lua"

local spawnType
local spawnSpacing

local playerPromises  ---@type table<EntityId, RpcPromise>

function init()
  spawnType = config.getParameter("spawnType")
  spawnSpacing = config.getParameter("spawnSpacing")

  playerPromises = {}
end

function update(dt)
  for _, playerId in ipairs(world.players()) do
    if not playerPromises[playerId] then
      playerPromises[playerId] = world.sendEntityMessage(playerId, "v-ministarheat-getSpawnRange")
    elseif playerPromises[playerId]:finished() and playerPromises[playerId]:succeeded() then
      local spawnRange = playerPromises[playerId]:result()
      spawnStagehands(spawnRange)
      stagehand.die()

      return
    end
  end
end

function spawnStagehands(spawnRange)
  local worldSize = world.size()
  local params = {spawnRegion = {-spawnSpacing / 2, -spawnSpacing / 2, spawnSpacing / 2, spawnSpacing / 2}}

  for x = 0, worldSize[1] - 1, spawnSpacing do
    for y = spawnRange[1], spawnRange[2], spawnSpacing do
      world.spawnStagehand({x, y}, spawnType, params)
    end
  end
end