require "/scripts/util.lua"
require "/scripts/vec2.lua"
require "/scripts/v-util.lua"
require "/scripts/v-ellipse.lua"

local MIN_SUBMERSION_AMOUNT = 0.9

local pieceProjectileType
local pieceProjectileParameters
local pieceProjectileCount
local pieceFuzzAngle
local pieceSpeedRange

local monsterType
local monsterParameters
local spawnRadius
local spawnTime

local requiredLiquidId
local requiredObjects
local requiredObjectDistance
local requiredBiomeBlocks

local spawned
local spawnTimer
local spawnedPieces

function init()
  pieceProjectileType = config.getParameter("pieceProjectileType")
  pieceProjectileParameters = config.getParameter("pieceProjectileParameters", {})
  pieceProjectileCount = config.getParameter("pieceProjectileCount")
  pieceFuzzAngle = util.toRadians(config.getParameter("pieceFuzzAngle", 0))
  pieceSpeedRange = config.getParameter("pieceSpeedRange")

  monsterType = config.getParameter("monsterType")
  monsterParameters = config.getParameter("monsterParameters", {})
  monsterParameters.level = monsterParameters.level or world.threatLevel()
  monsterParameters.behaviorConfig = sb.jsonMerge(monsterParameters.behaviorConfig or {}, {
    eatEntity = entity.id()
  })
  spawnRadius = config.getParameter("spawnRadius")
  spawnTime = config.getParameter("spawnTime")

  requiredLiquidId = config.getParameter("requiredLiquidId")
  requiredObjects = config.getParameter("requiredObjects")
  requiredObjectDistance = config.getParameter("requiredObjectDistance")
  requiredBiomeBlocks = getRequiredBiomeBlockIds()

  spawned = false
  spawnTimer = spawnTime

  spawnPieces()

  message.setHandler("kill", function()
    for _, pieceId in ipairs(spawnedPieces) do
      world.sendEntityMessage(pieceId, "kill")
    end
    projectile.die()
  end)
end

-- Updates the things related to spawning the eel.
function update(dt)
  spawnTimer = spawnTimer - dt
  -- If the projectile meets spawn conditions, the spawn timer is below or equal to zero, and the eel has not spawned
  -- yet...
  if meetsSpawnConditions() and not spawned and spawnTimer <= 0 then
    -- Pick a random point on a circle centered at the current position with a radius of spawnRadius, then use that as
    -- the spawn position for the eel.
    world.spawnMonster(monsterType, vEllipse.point(mcontroller.position(), spawnRadius, math.random() * 2 * math.pi),
        monsterParameters)
    spawned = true
  end
end

-- Spawns a bunch of cosmetic chunks
function spawnPieces()
  spawnedPieces = {}

  local baseAngle = vec2.angle(mcontroller.velocity())

  -- Spawn pieces, each with a random angle and speed.
  for _ = 1, pieceProjectileCount do
    local spawnAngle = baseAngle + util.randomInRange{-pieceFuzzAngle, pieceFuzzAngle}

    local params = copy(pieceProjectileParameters)
    params.speed = util.randomInRange(pieceSpeedRange)

    local pieceId = world.spawnProjectile(pieceProjectileType, mcontroller.position(), projectile.sourceEntity(),
        vec2.withAngle(spawnAngle), false, params)

    table.insert(spawnedPieces, pieceId)
  end
end

function getRequiredBiomeBlockIds()
  local biomeBlocks = config.getParameter("requiredBiomeBlocks")
  local biomeBlockIds = {}

  -- For each biome block name...
  for _, name in ipairs(biomeBlocks) do
    local blockConfig = root.materialConfig(name)

    -- If no config is found...
    if not blockConfig then
      -- Abort script and report error.
      error("Material with name '".. name .."' is a metamaterial or does not exist.")
    end

    table.insert(biomeBlockIds, blockConfig.config.materialId)
  end

  table.sort(biomeBlockIds)

  return biomeBlockIds
end

---Returns `true` if the projectile is in water, is at most `requiredObjectDistance` blocks away from an object with
---any of the names in `requiredObjects`, and will not result in more than one active eel, `false` otherwise.
function meetsSpawnConditions()
  local activeEel = world.getProperty("v-activeMutantEel")

  -- Stop and return `false` if there is an active eel
  if activeEel and world.entityExists(activeEel) then
    return false
  end

  local liquidLvl = world.liquidAt(mcontroller.position() --[[@as Vec2I]])
  -- Stop and return `false` if the projectile is not completely submersed in a liquid with ID `requiredLiquidId`
  if not liquidLvl or liquidLvl[1] ~= requiredLiquidId or liquidLvl[2] < MIN_SUBMERSION_AMOUNT then
    return false
  end

  if not containsRequiredObjects() then
    return false
  end

  local biomeBlocks = world.biomeBlocksAt(mcontroller.position() --[[@as Vec2I]])
  table.sort(biomeBlocks)

  if not voidedUtil.deepEquals(biomeBlocks, requiredBiomeBlocks) then
    return false
  end

  return true
end

---Returns `true` if the projectile is at most `requiredObjectDistance` blocks away from an object with any of the names
---in `requiredObjects`, `false` otherwise.
function containsRequiredObjects()
  for _, objName in ipairs(requiredObjects) do
    -- Query for any objects with name `objName`. Stop and return `true` if at least one such object exists.
    if #world.objectQuery(mcontroller.position(), requiredObjectDistance, {name = objName}) > 0 then
      return true
    end
  end

  return false
end