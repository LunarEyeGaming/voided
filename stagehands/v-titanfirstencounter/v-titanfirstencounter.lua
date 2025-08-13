require "/scripts/util.lua"

local masterId
local spawnDelay
local silenceFadeTime
local silenceRange
local monsterType
local monsterParameters

local timer
local prevPlayers

function init()
  masterId = config.getParameter("masterId")
  spawnDelay = config.getParameter("spawnDelay")
  silenceFadeTime = config.getParameter("silenceFadeTime")
  silenceRange = config.getParameter("silenceRange")
  monsterType = config.getParameter("monsterType")
  monsterParameters = config.getParameter("monsterParameters")
  monsterParameters.behaviorConfig = monsterParameters.behaviorConfig or {}
  monsterParameters.behaviorConfig.firstEncounter = true

  timer = spawnDelay
  prevPlayers = {}
end

function update(dt)
  if not world.entityExists(masterId) then
    stagehand.die()
  end

  stagehand.setPosition(world.entityPosition(masterId))

  timer = timer - dt

  if timer <= 0 then
    world.spawnMonster(monsterType, stagehand.position(), monsterParameters)
    stagehand.die()
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