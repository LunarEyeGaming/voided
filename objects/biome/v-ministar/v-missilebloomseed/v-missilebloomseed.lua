require "/scripts/rect.lua"

require "/scripts/v-entity.lua"

local oldInit = init or function() end
local oldUpdate = update or function() end
local oldSetStage = setStage or function() end
local oldDie = die or function() end

local MAX_TRACK_TICKS = 3

-- Parameters
local detectRegion
local keepRegionRect  -- Region in which to keep entities
local fireOnDeath

-- State variables
local positionData  -- Track projectile velocities manually.

function init()
  oldInit()

  keepRegionRect = rect.translate(rect.pad(config.getParameter("detectRegion"), config.getParameter("keepRegionPadding", 1.0)), object.position())
  detectRegion = vEntity.getRegionPoints(config.getParameter("detectRegion"))
  fireOnDeath = config.getParameter("fireOnDeath", true)

  positionData = {}
end

function update(dt)
  oldUpdate(dt)

  local stageConfig = getCurrentStage()

  if stageConfig.fireThreshold then
    local foundEntity = detectFastEntities(dt)

    if foundEntity and (not stageConfig.fireChance or math.random() < stageConfig.fireChance) then
      fireProjectiles(stageConfig)

      setStage(stageConfig.resetToStage + 1)
    end
  else
    animator.setParticleEmitterActive("hazard", false)
    positionData = {}
  end

  updatePositionData()
end

function die()
  oldDie()

  local stages = getStages()
  if fireOnDeath then
    local currentStageNum = storage.stage
    local currentStage = stages[currentStageNum]

    while currentStage.fireThreshold do
      fireProjectiles(currentStage)

      currentStageNum = currentStageNum - 1
      currentStage = stages[currentStageNum]
    end
  else
    local currentStageNum = storage.stage
    local currentStage = stages[currentStageNum]

    while currentStage.cascadeHarvest do
      harvest(currentStage.harvestPool)

      currentStageNum = currentStageNum - 1
      currentStage = stages[currentStageNum]
    end
  end
end

function setStage(stageNum)
  oldSetStage(stageNum)

  local stageConfig = getCurrentStage()

  animator.setParticleEmitterActive("hazard", stageConfig.activateHazardParticle)
end

function detectFastEntities(dt)
  local stageConfig = getCurrentStage()

  for _, entityId in ipairs(world.entityQuery(detectRegion[1], detectRegion[2], {includedTypes = {"mobile"}})) do
    local eType = world.entityType(entityId)
    if eType == "projectile" or eType == "itemDrop" then
      addPositionData(entityId)
    else
      if vec2.mag(world.entityVelocity(entityId)) > stageConfig.fireThreshold then
        return true
      end
    end
  end

  for _, positions in pairs(positionData) do
    if positions[MAX_TRACK_TICKS] and positions[1] then
      local speed = vec2.mag(averageVelocity(positions, dt))

      if speed > stageConfig.fireThreshold then
        return true
      end
    end
  end

  return false
end

function fireProjectiles(stage)
  local ownPos = object.position()
  for _ = 1, stage.projectileCount do
    local pos
    if stage.offsetRegion then
      pos = vec2.add(ownPos, rect.randomPoint(stage.offsetRegion))
    elseif stage.offset then
      pos = vec2.add(ownPos, stage.offset)
    else
      pos = ownPos
    end

    local angle = stage.angle or 0

    if stage.fuzzAngle then
      angle = angle + math.random() * 2 * stage.fuzzAngle - stage.fuzzAngle
    end

    angle = angle * math.pi / 180

    world.spawnProjectile(stage.projectileType, pos, entity.id(), vec2.withAngle(angle), false, stage.projectileParameters)
  end
end

function addPositionData(entityId)
  if not positionData[entityId] then
    positionData[entityId] = {world.entityPosition(entityId)}
  end
end

function updatePositionData()
  for entityId, positions in pairs(positionData) do
    if world.entityExists(entityId) and rect.contains(keepRegionRect, positions[1]) then
      if #positions == MAX_TRACK_TICKS then
        table.remove(positions, 1)
      end

      table.insert(positions, world.entityPosition(entityId))
    else
      positionData[entityId] = nil
    end
  end

  -- world.debugText("%s", positionData, object.position(), "green")
end

function averageVelocity(positions, dt)
  local sum = {0, 0}
  for i = 2, #positions do
    local posStart = positions[i - 1]
    local posEnd = positions[i]

    sum[1] = sum[1] + posEnd[1] - posStart[1]
    sum[2] = sum[2] + posEnd[2] - posStart[2]
  end

  sum[1] = sum[1] / (#positions * dt)
  sum[2] = sum[2] / (#positions * dt)

  return sum
end