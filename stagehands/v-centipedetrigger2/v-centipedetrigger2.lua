require "/scripts/stagehandutil.lua"

local notificationKind

function init()
  notificationKind = config.getParameter("notificationKind")

  if storage.triggered == nil then
    storage.triggered = false
  end
end

function update(dt)
  local players = broadcastAreaQuery({ includedTypes = {"player"} })

  -- If at least one player was queried and this stagehand has not been triggered yet...
  if #players > 0 and not storage.triggered then
    local centipedeId = world.loadUniqueEntity("v-centipedeboss")

    world.sendEntityMessage(centipedeId, "notify", {type = notificationKind})

    storage.triggered = true
  end
end