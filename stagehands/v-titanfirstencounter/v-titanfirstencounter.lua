require "/scripts/rect.lua"
require "/scripts/util.lua"

local broadcastArea
local masterId
local spawnDelay
local silenceFadeTime
local silenceRange
local monsterType
local monsterParameters

local timer
local prevPlayers

local REQUIRED_DUNGEON_ID = 65535
local REQUIRED_DUNGEON_ID2 = 65533

function init()
  broadcastArea = config.getParameter("broadcastArea")
  masterId = config.getParameter("masterId")
  spawnDelay = config.getParameter("spawnDelay")
  silenceFadeTime = config.getParameter("silenceFadeTime")
  silenceRange = config.getParameter("silenceRange")
  monsterType = config.getParameter("monsterType")
  monsterParameters = config.getParameter("monsterParameters")
  monsterParameters.behaviorConfig = monsterParameters.behaviorConfig or {}
  monsterParameters.behaviorConfig.firstEncounter = true
  monsterParameters.spawnAnywhere = true

  timer = spawnDelay
  prevPlayers = {}
end

function update(dt)
  if not world.entityExists(masterId) then
    stagehand.die()
    return
  end

  stagehand.setPosition(world.entityPosition(masterId))

  timer = timer - dt

  if timer <= 0 then
    world.spawnMonster(monsterType, stagehand.position(), monsterParameters)
    stagehand.die()
    return
  end

  local queried = world.entityQuery(stagehand.position(), silenceRange, {includedTypes = {"player"}})

  -- Stop music for players that are no longer queried.
  for _, playerId in ipairs(prevPlayers) do
    if not contains(queried, playerId) then
      world.sendEntityMessage(playerId, "v-dungeonmusicplayer-unsetOverride")  -- Unset override.
      world.sendEntityMessage(playerId, "stopAltMusic", silenceFadeTime)
    end
  end

  -- Start music for players that have just started being queried. Use v-dungeonmusicplayer-setOverride to avoid trouble
  -- with the dungeonmusicplayer script.
  for _, playerId in ipairs(queried) do
    if not contains(prevPlayers, playerId) then
      world.sendEntityMessage(playerId, "v-dungeonmusicplayer-setOverride", {}, silenceFadeTime)
    end
  end

  prevPlayers = queried
end

---Returns `true` if all spaces that the stagehand's broadcast area occupies have a dungeon ID of REQUIRED_DUNGEON_ID or
---REQUIRED_DUNGEON_ID2, `false` otherwise.
---@return boolean
function isInMonsterSpawnZone()
  local boundBox = rect.translate(broadcastArea, stagehand.position())

  for x = boundBox[1], boundBox[3] do
    for y = boundBox[2], boundBox[4] do
      local dungeonId = world.dungeonId({x, y})
      if dungeonId ~= REQUIRED_DUNGEON_ID and dungeonId ~= REQUIRED_DUNGEON_ID2 then
        return false
      end
    end
  end

  return true
end