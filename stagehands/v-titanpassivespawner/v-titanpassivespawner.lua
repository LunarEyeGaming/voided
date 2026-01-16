require "/scripts/v-world.lua"
require "/scripts/rect.lua"

local masterId
local monsterType
local monsterParameters

local location
local regionToLoad

function init()
  masterId = config.getParameter("masterId")
  monsterType = config.getParameter("monsterType")
  monsterParameters = config.getParameter("monsterParameters")
  monsterParameters.behavior = "v-titanofdarknesspassive"
  monsterParameters.spawnAnywhere = true

  local minPlayerDistance = config.getParameter("minPlayerDistance")
  local maxAttempts = config.getParameter("maxAttempts")
  local spawnRegion = config.getParameter("spawnRegion")
  location = spawnLocation(spawnRegion, minPlayerDistance, maxAttempts)

  if not location then
    location = {0, 100}
  end

  regionToLoad = rect.translate({-32, -32, 32, 32}, location)
end

function update(dt)
  if not world.entityExists(masterId) then
    stagehand.die()
    return
  end

  stagehand.setPosition(world.entityPosition(masterId))

  if world.loadRegion(regionToLoad) then
    world.spawnMonster(monsterType, location, monsterParameters)
    stagehand.die()
    return
  end
end

function spawnLocation(spawnRegion, minPlayerDistance, maxAttempts)
  local players = world.players()
  local positions = {}
  for _, playerId in ipairs(players) do
    local pos = world.entityPosition(playerId)
    if pos then
      table.insert(positions, pos)
    end
  end

  local region = rect.translate(spawnRegion, stagehand.position())
  region[2] = math.max(100, region[2])
  -- local region = {0, 100, world.size()[1], world.size()[2]}
  local spawnPos = vWorld.randomPositionInRegion(region, function(pos)
    for _, pos2 in ipairs(positions) do
      if world.magnitude(pos2, pos) < minPlayerDistance then
        return false
      end
    end
    return true
  end, maxAttempts)

  return spawnPos
end