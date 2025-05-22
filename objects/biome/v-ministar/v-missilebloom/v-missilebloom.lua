require "/scripts/rect.lua"
require "/scripts/vec2.lua"

require "/scripts/v-entity.lua"
require "/scripts/v-time.lua"

local MAX_TRACK_TICKS = 3

-- Parameters
local stages
local detectRegion
local keepRegionRect  -- Region in which to keep entities
local startingStage

-- State variables
local stageConfig  -- Config for the current stage
local positionData  -- Track projectile velocities manually.

function init()
  stages = config.getParameter("stages")
  keepRegionRect = rect.translate(rect.pad(config.getParameter("detectRegion"), config.getParameter("keepRegionPadding", 1.0)), object.position())
  detectRegion = vEntity.getRegionPoints(config.getParameter("detectRegion"))
  startingStage = config.getParameter("startingStage", 1)

  if not storage.stage then
    setStage(startingStage)
  end

  -- Initialize stage
  stageConfig = stages[storage.stage]
  if stageConfig.duration then
    storage.nextStageTime = world.time() + math.random(stageConfig.duration[1], stageConfig.duration[2])
  else
    storage.nextStageTime = nil
  end

  animator.setGlobalTag("stage", storage.stage - 1)

  if stageConfig.alts then
    animator.setGlobalTag("alt", sb.staticRandomI32Range(0, stageConfig.alts - 1, object.position()[1]))
  end

  positionData = {}

  vTime.addInterval(1, updateStage)
end

function update(dt)
  vTime.update(dt)

  -- world.debugText("%s", storage.stage, object.position(), "green")

  if stageConfig.fireThreshold then
    local foundEntity = detectFastEntities(dt)

    if foundEntity and (not stageConfig.fireChance or math.random() < stageConfig.fireChance) then
      fireProjectiles()

      setStage(stageConfig.resetToStage + 1)
    end
  else
    animator.setParticleEmitterActive("hazard", false)
    positionData = {}
  end

  updatePositionData()
end

function updateStage()
  if storage.nextStageTime and world.time() >= storage.nextStageTime then
    setStage(storage.stage + 1)
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

  animator.setParticleEmitterActive("hazard", stageConfig.activateHazardParticle)

  if stageConfig.alts then
    animator.setGlobalTag("alt", sb.staticRandomI32Range(0, stageConfig.alts - 1, object.position()[1]))
  else
    animator.setGlobalTag("alt", 0)
  end
end

function detectFastEntities(dt)
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

function fireProjectiles()
  local ownPos = object.position()
  for _ = 1, stageConfig.projectileCount do
    local pos
    if stageConfig.offsetRegion then
      pos = vec2.add(ownPos, rect.randomPoint(stageConfig.offsetRegion))
    elseif stageConfig.offset then
      pos = vec2.add(ownPos, stageConfig.offset)
    else
      pos = ownPos
    end

    local angle = stageConfig.angle or 0

    if stageConfig.fuzzAngle then
      angle = angle + math.random() * 2 * stageConfig.fuzzAngle - stageConfig.fuzzAngle
    end

    angle = angle * math.pi / 180

    world.spawnProjectile(stageConfig.projectileType, pos, entity.id(), vec2.withAngle(angle), false, stageConfig.projectileParameters)
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