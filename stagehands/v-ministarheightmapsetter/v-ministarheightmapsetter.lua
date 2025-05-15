require "/scripts/v-ministarutil.lua"

function init()
  local broadcastArea = config.getParameter("broadcastArea")
  local maxDepth = config.getParameter("maxDepth")

  local pos = stagehand.position()

  local startX = broadcastArea[1] + pos[1]
  local endX = broadcastArea[3] + pos[1]

  local heightMap = vMinistar.HeightMap:new(startX)
  for x = startX, endX do
    heightMap:set(x, maxDepth + pos[2])
  end

  vMinistar.setGlobalHeightMap(heightMap)

  stagehand.die()
end