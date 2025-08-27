require "/scripts/stagehandutil.lua"

-- TODO: Get rid of "self" subscripting.
local players
local music
local defaultMusic
local musicState

function init()
  players = {}
  music = config.getParameter("music", {})
  defaultMusic = config.getParameter("defaultMusic")
  musicState = "inactive"

  message.setHandler("setMusicState", function(_, _, state) return setMusicState(state) end)
end

function update(dt)
  for playerId, _ in pairs(players) do
    if not world.entityExists(playerId) then
      -- Player died or left the mission
      players[playerId] = nil
    end
  end

  local newPlayers = broadcastAreaQuery({ includedTypes = {"player"} })
  for _, playerId in pairs(newPlayers) do
    if not players[playerId] then
      playerEnteredBattle(playerId)
      players[playerId] = true
    end
  end
end

function playerEnteredBattle(playerId)
  if musicState == "active" then
    world.sendEntityMessage(playerId, "v-dungeonmusicplayer-setOverride", music, config.getParameter("fadeInTime"))
  elseif musicState == "partial" then
    world.sendEntityMessage(playerId, "v-dungeonmusicplayer-setOverride", jarray(), config.getParameter("startFadeOutTime"))
  end
end

function startMusic()
  for playerId, _ in pairs(players) do
    world.sendEntityMessage(playerId, "v-dungeonmusicplayer-setOverride", music, config.getParameter("fadeInTime"))
  end
end

function stopMusic()
  for playerId, _ in pairs(players) do
    world.sendEntityMessage(playerId, "v-dungeonmusicplayer-setOverride", jarray(), config.getParameter("endFadeOutTime"))
  end
end

function disableMusic()
  for playerId, _ in pairs(players) do
    if defaultMusic then
      world.sendEntityMessage(playerId, "v-dungeonmusicplayer-setOverride", defaultMusic, config.getParameter("fadeInTime"))
    else
      world.sendEntityMessage(playerId, "v-dungeonmusicplayer-unsetOverride", config.getParameter("endFadeOutTime"))
    end
  end
end

function setMusicState(state)
  if musicState ~= state then
    if state == "active" then
      startMusic()
    elseif state == "partial" then
      stopMusic()
    else
      disableMusic()
    end
    musicState = state
  end
end
