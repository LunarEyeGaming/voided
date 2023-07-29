require "/scripts/stagehandutil.lua"

-- TODO: Get rid of "self" subscripting.

function init()
  self.players = {}
  self.music = config.getParameter("music", {})
  self.defaultMusic = config.getParameter("defaultMusic")
  self.musicState = "inactive"

  message.setHandler("setMusicState", function(_, _, state) return setMusicState(state) end)
end

function update(dt)
  for playerId, _ in pairs(self.players) do
    if not world.entityExists(playerId) then
      -- Player died or left the mission
      self.players[playerId] = nil
    end
  end

  local newPlayers = broadcastAreaQuery({ includedTypes = {"player"} })
  for _, playerId in pairs(newPlayers) do
    if not self.players[playerId] then
      playerEnteredBattle(playerId)
      self.players[playerId] = true
    end
  end
end

function playerEnteredBattle(playerId)
  if self.musicState == "active" then
    world.sendEntityMessage(playerId, "playAltMusic", self.music, config.getParameter("fadeInTime"))
  elseif self.musicState == "partial" then
    world.sendEntityMessage(playerId, "playAltMusic", jarray(), config.getParameter("startFadeOutTime"))
  end
end

function startMusic()
  for playerId, _ in pairs(self.players) do
    world.sendEntityMessage(playerId, "playAltMusic", self.music, config.getParameter("fadeInTime"))
  end
end

function stopMusic()
  for playerId, _ in pairs(self.players) do
    world.sendEntityMessage(playerId, "playAltMusic", jarray(), config.getParameter("endFadeOutTime"))
  end
end

function disableMusic()
  for playerId, _ in pairs(self.players) do
    if self.defaultMusic then
      world.sendEntityMessage(playerId, "playAltMusic", self.defaultMusic, config.getParameter("fadeInTime"))
    else
      world.sendEntityMessage(playerId, "stopAltMusic", config.getParameter("endFadeOutTime"))
    end
  end
end

function setMusicState(state)
  if self.musicState ~= state then
    if state == "active" then
      startMusic()
    elseif state == "partial" then
      stopMusic()
    else
      disableMusic()
    end
    self.musicState = state
  end
end
