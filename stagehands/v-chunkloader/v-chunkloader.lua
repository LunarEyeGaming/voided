require "/scripts/util.lua"
require "/scripts/vec2.lua"
require "/scripts/rect.lua"
require "/scripts/stagehandutil.lua"

local QUERY_INTERVAL = 1.0

local loadRegion
local requirePlayerPresence
local hasPlayers

local queryTimer

function init()
  loadRegion = rect.translate(config.getParameter("loadArea"), config.getParameter("loadPosition", stagehand.position()))
  requirePlayerPresence = config.getParameter("requirePlayerPresence")
  hasPlayers = false

  queryTimer = QUERY_INTERVAL
end

function update(dt)
  if not requirePlayerPresence or hasPlayers then
    world.loadRegion(loadRegion)
    --sb.logInfo("active chunkloader: %s", entity.id())
  end

  -- Periodically update whether or not the chunk loader has players in it.
  queryTimer = queryTimer - dt

  if queryTimer <= 0 then
    hasPlayers = #broadcastAreaQuery({includedTypes = {"player"}}) > 0
    queryTimer = QUERY_INTERVAL
  end
end