require "/scripts/util.lua"
require "/scripts/vec2.lua"
require "/scripts/stagehandutil.lua"

--[[
  A script to override the dungeon music for players within the broadcast area. This script is intended to work with
  `/scripts/v-dungeonmusicplayer.lua`. The script works by sending a message to the dungeon music player of players who
  have just entered the broadcast area to start playing the override music instead of the music corresponding to a
  specific dungeon ID. Then, it sends a message to players that have just left the broadcast area to stop playing that
  music.
]]

local music
local fadeTime

local prevQueriedPlayers  -- A list of the players previously inside the broadcast area
local queriedPlayers  -- A list of the players currently inside the broadcast area

function init()
  music = config.getParameter("music")
  fadeTime = config.getParameter("fadeTime")

  queriedPlayers = {}
end

function update(dt)
  prevQueriedPlayers = queriedPlayers
  queriedPlayers = broadcastAreaQuery({includedTypes = {"player"}})

  -- Play music for all players who were not there in the previous tick.
  for _, playerId in ipairs(queriedPlayers) do
    if not contains(prevQueriedPlayers, playerId) then
      world.sendEntityMessage(playerId, "v-dungeonmusicplayer-setOverride", music, fadeTime)
    end
  end

  -- (Implicitly) stop music for all players who were there in the previous tick but not in the current tick.
  for _, playerId in ipairs(prevQueriedPlayers) do
    if not contains(queriedPlayers, playerId) then
      -- Disabling the override allows the dungeon music player script to take over.
      world.sendEntityMessage(playerId, "v-dungeonmusicplayer-unsetOverride")
    end
  end
end