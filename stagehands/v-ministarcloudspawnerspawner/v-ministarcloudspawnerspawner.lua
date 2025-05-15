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
      playerPromises[playerId] = world.sendEntityMessage(playerId, "v-ministarheat-getOceanLevel")
    elseif playerPromises[playerId]:finished() and playerPromises[playerId]:succeeded() then
      local oceanLevel = playerPromises[playerId]:result()
      spawnStagehands(oceanLevel)
      stagehand.die()

      return
    end
  end
end

function spawnStagehands(oceanLevel)
  local worldSize = world.size()

  for x = 0, worldSize[1] - 1, spawnSpacing do
    world.spawnStagehand({x, oceanLevel}, spawnType)
  end
end