require "/scripts/stagehandutil.lua"

local spawnPointPosition
local flyToPositionList
local circleAroundPosition
local behaviorType

function init()
  local spawnPointUid = config.getParameter("spawnPointUid")
  flyToPositionList = config.getParameter("flyToPositionList")
  circleAroundPosition = config.getParameter("circleAroundPosition")
  behaviorType = config.getParameter("monsterBehaviorType", "v-centipedebossbuildup")

  local positionId = world.loadUniqueEntity(spawnPointUid)

  -- If the position to spawn does not exist...
  if not positionId or not world.entityExists(positionId) then
    sb.logError("v-centipedetrigger: Failed to load entity with unique ID '%s'", spawnPointUid)
    stagehand.die()
  end

  spawnPointPosition = world.entityPosition(positionId)

  if storage.triggered == nil then
    storage.triggered = false
  end
end

function update(dt)
  local players = broadcastAreaQuery({ includedTypes = {"player"} })

  -- If at least one player was queried and this stagehand has not been triggered yet...
  if #players > 0 and not storage.triggered then
    -- Spawn the centipede boss, asking it to fly to the provided positions
    world.spawnMonster("v-centipedebosshead", spawnPointPosition, {
      behavior = behaviorType,
      behaviorConfig = {positionList = flyToPositionList, circlePosition = circleAroundPosition},
      persistent = true
    })

    storage.triggered = true
  end
end