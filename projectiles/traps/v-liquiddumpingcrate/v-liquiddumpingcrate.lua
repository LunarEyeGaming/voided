require "/scripts/vec2.lua"

local liquidId
local liquidQuantity
local liquidOffset
local liquidSpawnInterval
local maxPlayerDistance

local liquidSpawnTimer

function init()
  liquidId = config.getParameter("liquidId", 1)
  liquidQuantity = config.getParameter("liquidQuantity", 1)
  liquidOffset = config.getParameter("liquidOffset", {0, 0})
  liquidSpawnInterval = config.getParameter("liquidSpawnInterval", 0.04)
  maxPlayerDistance = config.getParameter("maxPlayerDistance")

  liquidSpawnTimer = liquidSpawnInterval
end

function update(dt)
  liquidSpawnTimer = liquidSpawnTimer - dt
  
  local liquidPos = vec2.add(mcontroller.position(), liquidOffset)

  -- If it is time to spawn the liquid and there is at least one player nearby...
  if liquidSpawnTimer <= 0 and playerNearby() then
    world.spawnLiquid(liquidPos, liquidId, liquidQuantity)
    liquidSpawnTimer = liquidSpawnInterval
  end
end

function playerNearby()
  for _, playerId in ipairs(world.players()) do
    if world.magnitude(mcontroller.position(), world.nearestTo(mcontroller.position(), world.entityPosition(playerId))) <= maxPlayerDistance then
      return true
    end
  end
  
  return false
end