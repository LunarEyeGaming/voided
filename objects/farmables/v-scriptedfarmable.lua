require "/scripts/vec2.lua"

require "/scripts/v-time.lua"

-- Parameters
local stages
local consumeSoilMoisture
local startingStage

-- State variables
local stageConfig  -- Config for the current stage

function init()
  stages = config.getParameter("stages")
  consumeSoilMoisture = config.getParameter("consumeSoilMoisture", true)
  startingStage = config.getParameter("startingStage", 1)

  if not storage.stage then
    setStage(startingStage)
  end

  -- Initialize stage
  stageConfig = stages[storage.stage]
  -- if stageConfig.duration then
  --   storage.nextStageTime = world.time() + math.random(stageConfig.duration[1], stageConfig.duration[2])
  -- else
  --   storage.nextStageTime = nil
  -- end

  animator.setGlobalTag("stage", storage.stage - 1)

  if stageConfig.alts then
    animator.setGlobalTag("alt", sb.staticRandomI32Range(0, stageConfig.alts - 1, object.position()[1]))
  else
    animator.setGlobalTag("alt", "0")
  end

  positionData = {}

  vTime.addInterval(1, updateStage)
end

function update(dt)
  vTime.update(dt)
end

function onInteraction()
  if stageConfig.cascadeHarvest then
    while stageConfig.cascadeHarvest do
      harvest(stageConfig.harvestPool)

      setStage(stageConfig.resetToStage + 1)
    end
  elseif stageConfig.harvestPool then
    harvest(stageConfig.harvestPool)

    setStage(stageConfig.resetToStage + 1)
  end
end

function updateStage()
  if storage.nextStageTime and world.time() >= storage.nextStageTime then
    -- Grow. Attempt to dry the soil if configured to do so. Upon failure, make it wait the full duration again for
    -- another attempt.
    if not consumeSoilMoisture or drySoil() then
      setStage(storage.stage + 1)
    else
      storage.nextStageTime = world.time() + math.random(stageConfig.duration[1], stageConfig.duration[2])
    end
  end
end

function setStage(stageNum)
  storage.stage = stageNum
  stageConfig = stages[stageNum]
  if stageConfig.duration then
    storage.nextStageTime = (storage.nextStageTime or world.time()) + math.random(stageConfig.duration[1], stageConfig.duration[2])
  else
    storage.nextStageTime = nil
  end

  animator.setGlobalTag("stage", stageNum - 1)

  if stageConfig.alts then
    animator.setGlobalTag("alt", sb.staticRandomI32Range(0, stageConfig.alts - 1, object.position()[1]))
  else
    animator.setGlobalTag("alt", 0)
  end

  object.setInteractive(stageConfig.harvestPool ~= nil)
end

function getStages()
  return stages
end

function getCurrentStage()
  return stageConfig
end

function harvest(pool)
  world.spawnTreasure(vec2.add(object.position(), {1, 1}), pool, world.threatLevel())
end

function getRootPositions()
  -- Find the lowest object space y values for each x value.
  local lowestSpaces = {}

  for _, space in ipairs(object.spaces()) do
    local x, y = space[1], space[2]
    if not lowestSpaces[x] then
      lowestSpaces[x] = y
    else
      lowestSpaces[x] = math.min(y, lowestSpaces[x])
    end
  end

  -- Build a list of the absolute positions based on lowestSpaces where each position is offset by -1 on the y-axis.
  local ownPos = object.position()
  local rootPositions = {}

  for x, y in pairs(lowestSpaces) do
    table.insert(rootPositions, {x + ownPos[1], y + ownPos[2] - 1})
  end

  return rootPositions
end

---Attempts to dry the soil. Returns whether or not it was successful. All anchor points for the object must contain a
---"tilled" (wet) matmod for it to be successful.
---@return boolean
function drySoil()
  local rootPositions = getRootPositions()

  -- Check if able to consume soil moisture. If not, do nothing and return false.
  for _, pos in ipairs(rootPositions) do
    local mod = world.mod(pos, "foreground")
    if mod ~= "tilled" then
      return false
    end
  end

  -- Consume soil moisture.
  for _, pos in ipairs(rootPositions) do
    world.placeMod(pos, "foreground", "tilleddry")
  end

  return true
end