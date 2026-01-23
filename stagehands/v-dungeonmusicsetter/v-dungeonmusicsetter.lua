require "/scripts/util.lua"
require "/scripts/vec2.lua"
require "/scripts/rect.lua"

-- TODO: Maybe add an option for using the current dungeon ID?
--[[
  A script to set the dungeon music for the current world. The world properties set here are used by
  /scripts/player/v-dungeonmusicplayer.lua.
]]

local regionToCheck

function init()
  regionToCheck = rect.translate(config.getParameter("broadcastArea"), stagehand.position())
end

function update(dt)
  if world.loadRegion(regionToCheck) then
    local dungeonMusic = config.getParameter("dungeonMusic", {})
    local dungeonMusicStopFadeTime = config.getParameter("dungeonMusicStopFadeTime", 2.0)

    if dungeonMusic.atOwnPosition then
      local dungeonId = world.dungeonId(stagehand.position())

      dungeonMusic[tostring(dungeonId)] = dungeonMusic.atOwnPosition
      dungeonMusic.atOwnPosition = nil
    end

    world.setProperty("v-dungeonMusic", dungeonMusic)
    world.setProperty("v-dungeonMusicStopFadeTime", dungeonMusicStopFadeTime)

    stagehand.die()
  end
end