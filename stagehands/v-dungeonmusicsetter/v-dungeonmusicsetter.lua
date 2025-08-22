require "/scripts/util.lua"
require "/scripts/vec2.lua"

-- TODO: Maybe add an option for using the current dungeon ID?
--[[
  A script to set the dungeon music for the current world. The world properties set here are used by
  /scripts/player/v-dungeonmusicplayer.lua.
]]

function init()
  world.setProperty("v-dungeonMusic", config.getParameter("dungeonMusic", {}))
  world.setProperty("v-dungeonMusicStopFadeTime", config.getParameter("dungeonMusicStopFadeTime", 2.0))

  stagehand.die()
end