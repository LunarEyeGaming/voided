require "/scripts/vec2.lua"

-- Parameters
local advanceInterval  ---@type number
local advanceDirection  ---@type -1 | 1

-- State variables
local advanceTimer  ---@type number
local signals  ---@type boolean[] List of signals for each horizontal position.

function init()
  advanceInterval = config.getParameter("advanceInterval")
  advanceDirection = config.getParameter("advanceDirection")

  advanceTimer = advanceInterval

  if not storage.spaces then
    setupMaterialSpaces()
  end

  signals = {}
  for _ = 1, #storage.spaces do
    table.insert(signals, false)
  end
end

function update(dt)
  advanceTimer = advanceTimer - dt

  if advanceTimer <= 0 then
    advanceSignals(object.getInputNodeLevel(0))
    object.setOutputNodeLevel(0, signals[#signals])

    advanceTimer = advanceInterval
  end
end

function advanceSignals(currentSignal)
  table.insert(signals, 1, currentSignal)
  table.remove(signals, #signals)

  -- Select the spaces from storage.partitionedSpaces that match.
  local spaces = {}

  for i, signal in ipairs(signals) do
    if signal then
      -- TODO: Handle advanceDirection
      for _, space in ipairs(storage.spaces[i]) do
        table.insert(spaces, space)
      end
    end
  end

  object.setMaterialSpaces(spaces)
end

function setupMaterialSpaces()
  local pos = entity.position()
  local spaces = object.spaces()

  -- Reorder spaces by x position.
  table.sort(spaces, function(v1, v2)
    return v1[1] < v2[1]
  end)

  -- Build material spaces.
  local materialSpaces = {}  ---@type [Vec2I, string][]
  for _, space in ipairs(spaces) do
    local mat = world.material(vec2.add(pos, space), "background")
    if not mat then
      mat = "metamaterial:empty"
    end
    table.insert(materialSpaces, {space, mat})
  end

  -- Partition material spaces by x position.
  local partitionedSpaces = {}  ---@type [Vec2I, string][][]
  table.insert(partitionedSpaces, {materialSpaces[1]})
  for i = 2, #materialSpaces do
    local lastPartition = partitionedSpaces[#partitionedSpaces]
    local partitionMatSpace = lastPartition[1]  -- An arbitrary material space from the partition
    local partitionSpace = partitionMatSpace[1]  -- The position of that space
    local matSpace = materialSpaces[i]  -- A material space
    local space = matSpace[1]  -- The position of that space

    if space[1] == partitionSpace[1] then
      table.insert(lastPartition, matSpace)
    else
      table.insert(partitionedSpaces, {matSpace})
    end
  end

  storage.spacesXStart = materialSpaces[1][1]
  storage.spaces = partitionedSpaces
end