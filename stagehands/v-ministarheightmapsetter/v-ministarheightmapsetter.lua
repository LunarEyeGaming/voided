local SECTOR_SIZE = 32

function init()
  local broadcastArea = config.getParameter("broadcastArea")
  local maxDepth = config.getParameter("maxDepth")

  local pos = stagehand.position()

  local startX = broadcastArea[1] + pos[1]
  local endX = broadcastArea[3] + pos[1]

  local startXSector = startX // SECTOR_SIZE
  local endXSector = endX // SECTOR_SIZE

  -- Map from horizontal positions to `HeightMapItem`.
  ---@type table<integer, HeightMapItem>
  local globalHeightMap = {}

  for xSector = startXSector, endXSector do
    local xSectorWrapped = world.xwrap(xSector * SECTOR_SIZE) // SECTOR_SIZE
    -- Get global height map section corresponding to `xSector`.
    local globalHeightMapSection = world.getProperty("v-globalHeightMap." .. xSectorWrapped) or {}

    -- Copy the section over to globalHeightMap.
    for _, value in ipairs(globalHeightMapSection) do
      globalHeightMap[value.x] = value.value
    end
  end

  for x = startX, endX do
    local xWrapped = world.xwrap(x)
    globalHeightMap[xWrapped] = maxDepth + pos[2]
  end

  -- Store globalHeightMap sections.
  for xSector = startXSector, endXSector do
    local globalHeightMapSection = {}
    local xSectorWrapped = world.xwrap(xSector * SECTOR_SIZE) // SECTOR_SIZE

    -- Copy corresponding x values over to the section.
    for x = xSectorWrapped * SECTOR_SIZE, (xSectorWrapped + 1) * SECTOR_SIZE - 1 do
      table.insert(globalHeightMapSection, {x = x, value = globalHeightMap[x]})
    end

    world.setProperty("v-globalHeightMap." .. xSectorWrapped, globalHeightMapSection)
  end

  stagehand.die()
end