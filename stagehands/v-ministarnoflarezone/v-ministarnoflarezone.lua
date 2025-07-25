require "/scripts/v-ministarutil.lua"

function init()
  local broadcastArea = config.getParameter("broadcastArea")

  local pos = stagehand.position()

  local startX = math.floor(broadcastArea[1] + pos[1])
  local endX = math.floor(broadcastArea[3] + pos[1])

  local noFlareZones = world.getProperty("v-noFlareZones") or {}

  table.insert(noFlareZones, {startX = startX, endX = endX})

  world.setProperty("v-noFlareZones", noFlareZones)

  stagehand.die()
end