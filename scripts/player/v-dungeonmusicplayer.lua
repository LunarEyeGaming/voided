--[[
  Plays music based on the dungeon ID of the tile located at the center of the player. To do this, a `playAltMusic`
  message is sent to the player when they enter a region with a dungeon ID registered in the `v-dungeonMusic` world
  property, and a `stopAltMusic` message is sent when they enter a region with a dungeon ID that is not registered in
  the `v-dungeonMusic` world property. The fade time for stopping music is defined through the
  `v-dungeonMusicStopFadeTime` property. If neither property is defined, then this script will do nothing, waiting for
  it to be defined. These properties are set using the `v-dungeonmusicsetter` stagehand.

  This script also has the option to override the music currently being played (through
  `v-dungeonmusicplayer-setOverride` and `v-dungeonmusicplayer-unsetOverride`). The first message disables the dungeon
  ID-based music functionality and plays the music given in the message. The second message re-enables it. The
  `playAltMusic` message is sent by this script to prevent network-related synchronization issues.
]]

local dungeonMusic
local stopAltMusicFadeTime
local prevDungeonId

local musicOverridden
local playingDungeonMusic

function init()
  musicOverridden = false

  message.setHandler("v-dungeonmusicplayer-setOverride", function(_, _, overrideMusic, fadeTime)
    -- Start override music.
    world.sendEntityMessage(player.id(), "playAltMusic", overrideMusic, fadeTime)
    musicOverridden = true
  end)

  message.setHandler("v-dungeonmusicplayer-unsetOverride", function()
    musicOverridden = false
  end)
end

function update(dt)
  dungeonMusic = world.getProperty("v-dungeonMusic")
  stopAltMusicFadeTime = world.getProperty("v-dungeonMusicStopFadeTime")

  -- If dungeonMusic or stopAltMusicFadeTime are not defined...
  if not dungeonMusic or not stopAltMusicFadeTime then
    -- Cancel the update for the current tick
    return
  end

  -- If the dungeon music player is overridden right now...
  if musicOverridden then
    -- Cancel the update for the current tick
    return
  end

  local dungeonId = world.dungeonId(mcontroller.position())

  -- If the dungeon ID changed...
  if prevDungeonId ~= dungeonId then
    -- The dungeonMusic object contains string keys, but dungeonId is a number, so it has to be converted to a string.
    local dungeonMusicEntry = dungeonMusic[tostring(dungeonId)]
    -- If the dungeon music for the current dungeon ID is defined...
    if dungeonMusicEntry then
      -- Play the music
      world.sendEntityMessage(player.id(), "playAltMusic", dungeonMusicEntry.music, dungeonMusicEntry.fadeTime)
      playingDungeonMusic = true
    else
      -- If dungeon music is playing...
      if playingDungeonMusic then
        -- Stop the music
        world.sendEntityMessage(player.id(), "stopAltMusic", stopAltMusicFadeTime)
      end
      playingDungeonMusic = false
    end
  end

  prevDungeonId = dungeonId
end