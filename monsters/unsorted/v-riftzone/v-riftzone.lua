require "/scripts/vec2.lua"
require "/scripts/interp.lua"
require "/scripts/util.lua"
require "/scripts/rect.lua"

require "/scripts/v-attack.lua"
require "/scripts/v-animator.lua"
require "/scripts/v-vec2.lua"

local INSTANT_BREAK_DAMAGE = 2 ^ 32
local MAX_TILES_TO_DESTROY = 2000
local CELL_SIZE = 8

-- Parameters
local scanRadius
local tileSofteningRadius
local invisibleOre
local visibleOre
local terrainMaterial
local lightBlockerMaterial
local appearTime
local disappearTime
local disappearDelay
local timeToLive
local initialVelocity
local velocity
local playerProximityRegion
local terrainZRange
local relocationProbability
local lightningStrikeProbability
local monsterSpawns

-- State variables
local prevPos
local prevRadius
local currentScanRadius
local currentTileSofteningRadius
local existenceTimer

local lightningController
local terrainPerlinSource
local oreFGPerlinSource
local oreBGPerlinSource
local placedBlocksFG
local placedBlocksBG
local placedOresFG
local placedOresBG
local placedAssists
local frontScanPositions
local backScanPositions
local cachedFrontScanPositions
local cachedBackScanPositions
local cleanedUp
local dungeonIdsToRevert

local weatherFunctions
local weatherConfigs

local weatherFunction
local weatherConfig

local state

local deferredTasks

local wasForceKilled
local initialized

function init()
  local cfg = root.assetJson("/v-riftzones.config")
  cfg = sb.jsonMerge(cfg, config.getParameter("configOverrides", {}))
  scanRadius = cfg.defaultZoneRadius
  tileSofteningRadius = config.getParameter("tileSofteningRadius")
  monster.setAnimationParameter("riftSize", 0)
  invisibleOre = cfg.invisibleOre
  visibleOre = cfg.visibleOre
  terrainMaterial = config.getParameter("terrainMaterial")
  lightBlockerMaterial = config.getParameter("lightBlockerMaterial")
  appearTime = config.getParameter("appearTime")
  disappearTime = config.getParameter("disappearTime")
  disappearDelay = config.getParameter("disappearDelay")
  timeToLive = config.getParameter("timeToLive", 300)
  initialVelocity = config.getParameter("velocity", {0, 0})
  velocity = initialVelocity
  playerProximityRegion = config.getParameter("playerProximityRegion")
  terrainZRange = config.getParameter("terrainZRange")
  relocationProbability = cfg.relocationProbability
  lightningStrikeProbability = config.getParameter("lightningStrikeProbability")
  monsterSpawns = config.getParameter("monsterSpawns", {})

  for _, spawn in ipairs(monsterSpawns) do
    local monsterCfg = root.monsterParameters(spawn.monsterType)

    local movementSettings = root.assetJson("/default_actor_movement.config")
    movementSettings = sb.jsonMerge(movementSettings, monsterCfg.movementSettings)

    spawn.testPoly = movementSettings.collisionPoly
    spawn.maxCorrection = movementSettings.maximumCorrection
  end

  cachedFrontScanPositions = {}
  cachedBackScanPositions = {}

  prevPos = vec2.floor(mcontroller.position())
  prevRadius = 0
  currentScanRadius = 0
  currentTileSofteningRadius = 0
  existenceTimer = timeToLive
  g_shouldDieVar = false

  local lgCfg = config.getParameter("lightningConfig", {})

  lightningController = vAnimator.LightningController:new{
    cfg = lgCfg.baseConfig,
    startC = lgCfg.startColor,
    endC = lgCfg.endColor,
    dur = lgCfg.duration,
    animateManually = false,
    startOC = lgCfg.startOutlineColor,
    endOC = lgCfg.endOutlineColor,
  }
  terrainPerlinSource = makePerlinSource("terrainPerlinSource")
  oreFGPerlinSource = makePerlinSource("oreFGPerlinSource")
  oreBGPerlinSource = makePerlinSource("oreBGPerlinSource")
  placedBlocksFG = {}
  placedBlocksBG = {}
  placedOresFG = {}
  placedOresBG = {}
  placedAssists = {}
  dungeonIdsToRevert = {}

  weatherFunctions = {
    meteors = function()
      spawnMeteors(weatherConfig, currentScanRadius)
    end,
    gravispheres = function()
      spawnGravispheres(weatherConfig, currentScanRadius)
    end,
    destabilization = function()
      animator.setParticleEmitterActive("emptyWind", true)
      applyEffect(weatherConfig.statusEffect, currentScanRadius, {"creature"})
    end
  }
  weatherConfigs = config.getParameter("weatherConfigs")

  local weatherName = world.getProperty("v-riftZoneWeather") or "destabilization"

  weatherFunction = weatherFunctions[weatherName]
  if not weatherFunction then
    error(string.format("Function not found for rift zone weather: %s", weatherName))
  end
  weatherConfig = weatherConfigs[weatherName]
  if not weatherConfig then
    error(string.format("Config not found for rift zone weather: %s", weatherName))
  end

  message.setHandler("v-riftzone-kill", v_killRiftZone)

  monster.setDamageBar("None")
  state = FSM:new()
  state:set(states.postInit)

  deferredTasks = {}

  initialized = true
end

function update(dt)
  if not initialized then return end

  revertDungeonIds()
  callDeferredTasks()

  state:update(dt)

  lightningController:update(dt)

  -- if world.players()[1] and not world.entityExists(world.players()[1]) then
  --   sb.logInfo("Spawning monster")
  --   world.spawnMonster("v-riftzonecleanup", mcontroller.position(), {persistent = true})
  -- end

  -- Suppress updates to tiles if too far away from any players to prevent loading chunks, causing a chain reaction of
  -- rift zones loading into existence.
  if closeToAPlayer(mcontroller.position()) then
    updateDeltaScans(currentScanRadius)
    updateMaterials(currentScanRadius)
    updateWeather(dt)
    spawnMonsters()
  end

  -- applyEffect("v-softenedtiles", currentTileSofteningRadius, {"player"})
  applyEffect("v-rifteffects", currentScanRadius, {"player"})

  crackleLightning(currentTileSofteningRadius)

  monster.setAnimationParameter("riftSize", currentScanRadius + 1)

  local placedBlocksCount = 0
  local placedBlocksBGCount = 0
  local placedAssistsCount = 0
  for _, _ in pairs(placedBlocksFG) do
    placedBlocksCount = placedBlocksCount + 1
  end
  for _, _ in pairs(placedBlocksBG) do
    placedBlocksBGCount = placedBlocksBGCount + 1
  end
  for _, _ in pairs(placedAssists) do
    placedAssistsCount = placedAssistsCount + 1
  end
  world.debugText("placedBlocks: %s\nplacedBlocksBG: %s\nplacedAssists: %s", placedBlocksCount, placedBlocksBGCount, placedAssistsCount, mcontroller.position(), "green")

  -- world.loadRegion(rect.translate({-32, -32, 32, 32}, mcontroller.position()))
end

function shouldDie()
  return g_shouldDieVar
end

function uninit()
  cleanUp()
end

states = {}

function states.postInit()
  for _ = 1, 2 do
    coroutine.yield()
  end

  notifyRiftZoneSpawned()

  setExistenceTimer()
  if wasForceKilled then
    state:set(states.die)
  elseif existenceTimer <= -disappearTime then
    state:set(states.die)
  elseif existenceTimer <= 0 then
    fillMatMods(scanRadius)
    state:set(states.disappear)
  elseif existenceTimer >= timeToLive - appearTime then
    state:set(states.appear)
  else
    fillMatMods(scanRadius)
    state:set(states.move)
  end
end

function states.appear()
  animator.playSound("open")

  local prevScanRadius = 0
  local timer = 0
  while timer < appearTime do
    currentScanRadius = interp.sin(timer / appearTime, 0, scanRadius)
    currentTileSofteningRadius = interp.sin(timer / appearTime, 0, tileSofteningRadius)

    local ownPos = vec2.floor(mcontroller.position())
    computeDeltaScans(prevScanRadius, currentScanRadius, ownPos, ownPos)

    timer = timer + script.updateDt()

    prevScanRadius = currentScanRadius

    coroutine.yield()
  end

  state:set(states.move)
end

function states.move()
  currentScanRadius = scanRadius
  currentTileSofteningRadius = tileSofteningRadius

  local ownPos = vec2.floor(mcontroller.position())
  -- local normVel = vec2.norm(velocity)
  -- sb.logInfo(string.format("%.7f, %.7f", normVel[1], normVel[2]))
  -- local nextPos = vec2.add(ownPos, {-1, 0})
  local nextPos = vec2.floor(vec2.add(vec2.add(ownPos, vec2.norm(velocity)), {0.5, 0.5}))
  computeDeltaScans(currentScanRadius, currentScanRadius, ownPos, nextPos)

  -- rotationTimer = 0

  while existenceTimer > 0 do
    -- rotationTimer = (rotationTimer + script.updateDt()) % rotationPeriod
    -- velocity = vec2.rotate(initialVelocity, rotationTimer * 2 * math.pi / rotationPeriod)
    mcontroller.setVelocity(velocity)

    existenceTimer = existenceTimer - script.updateDt()

    coroutine.yield()
  end

  state:set(states.disappear)
end

function states.disappear()
  animator.playSound("close")

  if wasForceKilled then
    mcontroller.setVelocity({0, 0})
  end

  util.wait(disappearDelay)

  mcontroller.setVelocity({0, 0})

  local prevScanRadius = 0
  local timer = disappearTime
  while timer > 0 do
    currentScanRadius = interp.sin(timer / disappearTime, 0, scanRadius)
    currentTileSofteningRadius = interp.sin(timer / disappearTime, 0, tileSofteningRadius)

    local ownPos = vec2.floor(mcontroller.position())
    computeDeltaScans(prevScanRadius, currentScanRadius, ownPos, ownPos)

    timer = timer - script.updateDt()

    prevScanRadius = currentScanRadius

    coroutine.yield()
  end

  currentScanRadius = 0
  currentTileSofteningRadius = 0

  state:set(states.die)
end

function states.die()
  g_shouldDieVar = true

  if math.random() < relocationProbability then
    local riftZones = world.getProperty("v-riftZones") or jarray()
    createRiftZone(riftZones)
    world.setProperty("v-riftZones", riftZones)
  end

  -- The script should stop running within the next tick or two. This just ensures the coroutine doesn't die prematurely
  -- and cause an error.
  while true do
    coroutine.yield()
  end
end

function callDeferredTasks()
  for i = #deferredTasks, 1, -1 do
    local task = deferredTasks[i]
    if type(task) == "table" then
      task.ticks = task.ticks - 1
      if task.ticks <= 0 then
        task.func()
        table.remove(deferredTasks, i)
      end
    else
      task()
      table.remove(deferredTasks, i)
    end
  end
end

function createRiftZone(riftZones)
  local size = world.size()
  local pos = {math.random() * size[1], math.random() * size[2]}
  local deathTime = world.time() + timeToLive
  table.insert(riftZones, {
    position = pos,
    velocity = initialVelocity,
    stateData = {deathTime = deathTime},
    level = monster.level(),
    timeToLive = timeToLive
  })
end

function crackleLightning(radius)
  if math.random() < lightningStrikeProbability then
    local randomPosStart = vec2.add(mcontroller.position(), vec2.withAngle(math.random() * 2 * math.pi, math.random() * radius))
    local randomPosEnd = vec2.add(mcontroller.position(), vec2.withAngle(math.random() * 2 * math.pi, math.random() * radius))

    lightningController:addRandomSeed(randomPosStart, randomPosEnd)

    animator.playSound("crackle")
  end
end

function notifyRiftZoneSpawned()
  local players = world.players()

  for _, playerId in ipairs(players) do
    world.sendEntityMessage(playerId, "v-riftZoneSpawned")
  end
end

function setExistenceTimer()
  if wasForceKilled then
    return
  end

  local deathTime = config.getParameter("stateData.deathTime")
  if not deathTime then
    existenceTimer = timeToLive
  else
    existenceTimer = deathTime - world.time()
  end
end

function updateWeather(dt)
  -- applyRiftDestabilization(currentScanRadius)
  -- spawnMeteors(currentScanRadius)
  -- spawnGravispheres()
  weatherFunction()
end

function spawnMeteors(cfg, spawnRadius)
  if math.random() < cfg.spawnProbability then
    local appearDelay = cfg.appearDelay
    local speed = cfg.projectileSpeed
    local spawnBaseAngle = util.toRadians(cfg.spawnLocationAngle)
    local spawnFuzzAngle = util.toRadians(cfg.spawnLocationFuzzAngle)
    local spawnDirectionAngle = util.toRadians(cfg.spawnDirectionAngle)
    local spawnDirectionFuzzAngle = util.toRadians(cfg.spawnDirectionFuzzAngle)
    local spawnAngle = vVec2.randomAngle(spawnBaseAngle, spawnFuzzAngle)

    local appearPoint = vec2.withAngle(spawnAngle, spawnRadius)
    local spawnDirection = vec2.withAngle(vVec2.randomAngle(spawnDirectionAngle, spawnDirectionFuzzAngle))
    local spawnPoint = vec2.add(appearPoint, vec2.mul(spawnDirection, -speed * appearDelay))
    local spawnPointWorld = vec2.add(mcontroller.position(), spawnPoint)
    world.spawnProjectile(cfg.projectileType, spawnPointWorld, entity.id(), spawnDirection, false, {
      power = vAttack.scaledPower(cfg.projectilePower or 10),
      speed = speed,
      appearDelay = appearDelay
    })
  end
end

function spawnGravispheres(cfg, spawnRadius)
  if math.random() < cfg.spawnProbability then
    local ownPos = mcontroller.position()
    local requiredRegion = cfg.requiredSpawnRegion
    local maxAttempts = cfg.maxPositionSelectionAttempts
    local attempts = 0
    local randomPos
    repeat
      randomPos = vec2.add(ownPos, vec2.withAngle(math.random() * 2 * math.pi, math.random() * spawnRadius))
      attempts = attempts + 1
    until attempts > maxAttempts or not world.rectCollision(rect.translate(requiredRegion, randomPos))

    if attempts <= maxAttempts then
      world.spawnProjectile(cfg.projectileType, randomPos, entity.id(), {1, 0}, false, {
        power = vAttack.scaledPower(cfg.projectilePower or 10)
      })
    end
  end
end

function spawnMonsters()
  for _, pos in ipairs(frontScanPositions) do
    if pos[1] % CELL_SIZE == 0 and pos[2] % CELL_SIZE == 0 then
      for _, spawn in ipairs(monsterSpawns) do
        if math.random() < spawn.spawnChance then
          pos = rect.randomPoint(rect.translate({0, 0, CELL_SIZE, CELL_SIZE}, pos))
          if spawn.mode == "surface" then
            local spawnPos = world.resolvePolyCollision(spawn.testPoly, pos, spawn.maxCorrection)
            -- If the position was moved then it is guaranteed to be in a surface.
            if spawnPos and world.magnitude(spawnPos, pos) > 0.1 then
              local params = copy(spawn.monsterParameters)
              params.level = monster.level()
              world.spawnMonster(spawn.monsterType, spawnPos, params)
            end
          elseif spawn.mode == "air" then
            local spawnPos = world.resolvePolyCollision(spawn.testPoly, pos, spawn.maxCorrection)
            if spawnPos then
              local params = copy(spawn.monsterParameters)
              params.level = monster.level()
              world.spawnMonster(spawn.monsterType, spawnPos, params)
            end
          end
        end
      end
    end
  end
end

function applyEffect(effectName, radius, onTypes)
  local queried = world.entityQuery(mcontroller.position(), radius, {
    includedTypes = onTypes,
    withoutEntityId = entity.id()
  })

  for _, entityId in ipairs(queried) do
    world.sendEntityMessage(entityId, "applyStatusEffect", effectName)
  end
end

function updateDeltaScans(radius)
  radius = math.floor(radius)
  local ownPos = vec2.floor(mcontroller.position())
  world.debugPoint(ownPos, "green")

  -- for x = ownPos[1] - radius, ownPos[1] + radius do
  --   for y = ownPos[2] - radius, ownPos[2] + radius do
  --     local frontScanPos = {x, y}

  --     local dungeonId = world.dungeonId(frontScanPos)
  --     world.debugPoint(frontScanPos, dungeonId == 65535 and "green" or "red")
  --   end
  -- end

  frontScanPositions = {}
  backScanPositions = {}
  -- if radius ~= radiusSinceLastCache or not vec2.eq(velocitySinceLastCache or {}, mcontroller.velocity()) then
  --   local nextPos = vec2.floor(vec2.add(vec2.add(ownPos, vec2.norm(mcontroller.velocity())), {0.5, 0.5}))
  --   computeDeltaScans(prevRadius, radius, ownPos, nextPos)
  --   radiusSinceLastCache = radius
  --   velocitySinceLastCache = mcontroller.velocity()
  --   sb.logInfo("%s, %s", #cachedFrontScanPositions, #cachedBackScanPositions)
  -- end

  if ownPos[1] ~= prevPos[1] or ownPos[2] ~= prevPos[2] or radius ~= prevRadius then
    for _, pos in ipairs(cachedFrontScanPositions) do
      table.insert(frontScanPositions, vec2.add(pos, ownPos))
    end
    for _, pos in ipairs(cachedBackScanPositions) do
      table.insert(backScanPositions, vec2.add(pos, prevPos))
    end
  end

  prevPos = ownPos
  prevRadius = radius
end

function computeDeltaScans(radius0, radius, center0, center)
  radius0 = math.floor(radius0)
  radius = math.floor(radius)
  center0 = vec2.floor(center0)
  center = vec2.floor(center)

  cachedFrontScanPositions = {}
  cachedBackScanPositions = {}

  for x = -radius, radius do
    for y = -radius, radius do
      local frontScanPos = {center[1] + x, center[2] + y}

      local frontScanDist = world.magnitude(center, frontScanPos)
      local frontScanDist2 = world.magnitude(center0, frontScanPos)
      if frontScanDist <= radius and frontScanDist2 > radius0 then
        table.insert(cachedFrontScanPositions, {x, y})
      end
    end
  end

  for x = -radius, radius do
    for y = -radius, radius do
      local backScanPos = {center0[1] + x, center0[2] + y}

      local backScanDist = world.magnitude(center, backScanPos)
      local backScanDist2 = world.magnitude(center0, backScanPos)
      if backScanDist > radius and backScanDist2 <= radius0 then
        table.insert(cachedBackScanPositions, {x, y})
      end
    end
  end
end

function updateMaterials(radius)
  radius = math.floor(radius)
  local ownPos = vec2.floor(mcontroller.position())
  world.debugPoint(ownPos, "green")

  -- placeOres()

  -- placeBlocks()

  -- for _, frontScanPos in ipairs(frontScanPositions) do
  --   world.debugPoint(frontScanPos, "green")
  --   attemptPlaceMatMod(frontScanPos)
  --   if not world.material(frontScanPos, "foreground") and shouldPlaceBlock(frontScanPos) then
  --     table.insert(fgBlocksToPlace, frontScanPos)
  --     placedBlocksFG[vVec2.iToString(frontScanPos)] = true
  --     placedBlocksBG[vVec2.iToString(frontScanPos)] = true
  --   end
  -- end

  -- placeAssists()

  local blocksToPlaceFG = {}
  local blocksToPlaceBG = {}
  local oresToPlaceFG = {}
  local oresToPlaceBG = {}

  for _, frontScanPos in ipairs(frontScanPositions) do
    world.debugPoint(frontScanPos, "green")
    -- if shouldPlaceBlock(frontScanPos) then
    --   table.insert(blocksToPlaceFG, )
    -- end
    if shouldPlaceBlock(frontScanPos) then
      table.insert(blocksToPlaceFG, {pos = frontScanPos, material = terrainMaterial})
      table.insert(blocksToPlaceBG, {pos = frontScanPos, material = terrainMaterial})
      if oreFGPerlinSource:get(frontScanPos[1], frontScanPos[2]) > 0 then
        table.insert(oresToPlaceFG, frontScanPos)
      end
      if oreBGPerlinSource:get(frontScanPos[1], frontScanPos[2]) > 0 then
        table.insert(oresToPlaceBG, frontScanPos)
      end
    else
      table.insert(blocksToPlaceBG, {pos = frontScanPos, material = lightBlockerMaterial})
    end
  end

  placeBlocks(blocksToPlaceFG, placedBlocksFG, true)
  -- Defer to next update to avoid interference
  table.insert(deferredTasks, function()
    placeBlocks(blocksToPlaceBG, placedBlocksBG, false)
  end)

  table.insert(deferredTasks, {ticks = 2, func = function()
    placeOres(oresToPlaceFG, oresToPlaceBG)
  end})

  local blocksToRemove = {}
  local blocksToRemoveBG = {}

  for _, backScanPos in ipairs(backScanPositions) do
    world.debugPoint(backScanPos, "green")
    attemptRemoveMatMod(backScanPos)
    if placedBlocksFG[vVec2.iToString(backScanPos)] then
      table.insert(blocksToRemove, backScanPos)
      placedBlocksFG[vVec2.iToString(backScanPos)] = nil
    end
    if placedBlocksBG[vVec2.iToString(backScanPos)] then
      table.insert(blocksToRemoveBG, backScanPos)
      placedBlocksBG[vVec2.iToString(backScanPos)] = nil
    end
  end

  world.damageTiles(blocksToRemove, "foreground", mcontroller.position(), "blockish", INSTANT_BREAK_DAMAGE, 0)
  world.damageTiles(blocksToRemoveBG, "background", mcontroller.position(), "blockish", INSTANT_BREAK_DAMAGE, 0)

  -- table.insert(deferredTasks, {ticks = 1, func = function()
  --   recordDungeonIdsToRevert(blocksToRemove)
  --   recordDungeonIdsToRevert(blocksToRemoveBG)
  -- end})
  recordDungeonIdsToRevert(blocksToRemove)
  recordDungeonIdsToRevert(blocksToRemoveBG)

  -- world.setDungeonId(rect.translate({-radius, -radius, radius, radius}, prevPos), 65535)

  prevPos = ownPos
  prevRadius = radius
end

function recordDungeonIdsToRevert(blocks)
  for _, block in ipairs(blocks) do
    local blockStr = vVec2.iToString(block)
    dungeonIdsToRevert[blockStr] = world.dungeonId(block)
  end
end

function revertDungeonIds()
  -- Revert dungeon ID
  for blockStr, dungeonId in pairs(dungeonIdsToRevert) do
    local block = vVec2.iFromString(blockStr)
    -- world.debugText("%s", dungeonId, block, "green")
    world.setDungeonId({block[1], block[2], block[1] + 1, block[2] + 1}, dungeonId)
  end

  dungeonIdsToRevert = {}
end

function placeOres(fg, bg)
  if fg then
    for _, block in ipairs(fg) do
      local blockString = vVec2.iToString(block)
      if placedBlocksFG[blockString] then
        world.placeMod(block, "foreground", visibleOre)
        placedOresFG[vVec2.iToString(block)] = true
      end
    end
  end

  if bg then
    for _, block in ipairs(bg) do
      local blockString = vVec2.iToString(block)
      if placedBlocksBG[blockString] then
        world.placeMod(block, "background", visibleOre)
        placedOresBG[vVec2.iToString(block)] = true
      end
    end
  end
end

function shouldPlaceBlock(pos)
  local z = terrainPerlinSource:get(pos[1], pos[2])
  if terrainZRange[1] <= z and z <= terrainZRange[2] then
    z = 1
  else
    z = 0
  end

  return z > 0
end

function placeBlocks(blocksToPlace, placedBlocks, foreground)
  local currentLayer = foreground and "foreground" or "background"
  local oppositeLayer = foreground and "background" or "foreground"
  -- Filter out tiles that are occupied
  blocksToPlace = util.filter(blocksToPlace, function(block)
    return not world.tileIsOccupied(block.pos, foreground)
  end)
  -- Sort blocksToPlace by y-level (descending order)
  table.sort(blocksToPlace, function(a, b) return a.pos[2] > b.pos[2] end)
  local blocksToPlaceSet = {}
  for _, block in ipairs(blocksToPlace) do
    blocksToPlaceSet[vVec2.iToString(block.pos)] = true
  end
  -- Find blocks that require placement assists (by simply checking if the block above will be placed or is solid, or if
  -- there is a block in the opposite layer at that position)
  local needAssists = {}
  for _, block in ipairs(blocksToPlace) do
    local pos = block.pos
    local abovePos = {pos[1], pos[2] + 1}
    if not world.material(abovePos, currentLayer) and not world.material(pos, oppositeLayer) and not blocksToPlaceSet[vVec2.iToString(abovePos)] then
      table.insert(needAssists, block)
    end
  end

  -- Place assists where necessary. Mark as placed in placedBlocks
  for _, block in ipairs(needAssists) do
    local dungeonId = world.dungeonId(block.pos)  -- Record dungeonId BEFORE placing the material.
    local placedObject
    if foreground then
      -- TODO: Fix place assists interfering with each other
      world.debugPoint(block.pos, "yellow")
      placedObject = world.placeObject("terra_placeassist", {block.pos[1], block.pos[2] + 1} --[[@as Vec2I]], nil, {
        material = block.material,
        overlap = true,
        placeBehind = false,
        layer = "foreground"
      })
    else
      placedObject = world.placeObject("terra_placeassist", block.pos --[[@as Vec2I]], nil, {
        material = block.material,
        overlap = true,
        placeBehind = true
      })
    end
    if not placedObject then
      world.debugText("BLOCKED", block.pos, "red")
    else
      local blockStr = vVec2.iToString(block.pos)
      placedBlocks[blockStr] = true
      if not dungeonIdsToRevert[blockStr] then
        dungeonIdsToRevert[blockStr] = dungeonId
      end
    end
  end

  -- Defer to next update
  table.insert(deferredTasks, function()
    for _, block in ipairs(blocksToPlace) do
      if not placedBlocks[vVec2.iToString(block.pos)] then
        local dungeonId = world.dungeonId(block.pos)  -- Record dungeonId BEFORE placing the material.
        local success = world.placeMaterial(block.pos, currentLayer, block.material)
        if success then
          local blockStr = vVec2.iToString(block.pos)
          placedBlocks[blockStr] = true
          if not dungeonIdsToRevert[blockStr] then
            dungeonIdsToRevert[blockStr] = dungeonId
          end
        else
          world.debugText("FAILED", block.pos, "red")
        end
      end
    end
  end)
end

function fillMatMods(radius)
  radius = math.floor(radius)
  local ownPos = vec2.floor(mcontroller.position())

  for x = -radius, radius do
    for y = -radius, radius do
      local scanPos = vec2.add(ownPos, {x, y})

      local scanDist = world.magnitude(ownPos, scanPos)
      if scanDist <= radius then
        attemptPlaceMatMod(scanPos)
      end
    end
  end
end

function cleanUp()
  if not cleanedUp then
    if not initialized then return end

    clearMatMods(scanRadius)
    local blocksToClearFG = getBlocksToClear(placedBlocksFG, "foreground")
    if not blocksToClearFG then return
      sb.logWarn("blocksToClearFG not defined")
    end
    local blocksToClearBG = getBlocksToClear(placedBlocksBG, "background")
    if not blocksToClearBG then return
      sb.logWarn("blocksToClearBG not defined")
    end
    local oresToClearFG = getOresToClear(placedOresFG, "foreground")
    if not oresToClearFG then return
      sb.logWarn("oresToClearFG not defined")
    end
    local oresToClearBG = getOresToClear(placedOresBG, "background")
    if not oresToClearBG then return
      sb.logWarn("oresToClearBG not defined")
    end

    local riftZoneData
    if not g_shouldDieVar then
      riftZoneData = {
        position = mcontroller.position(),
        velocity = velocity,
        stateData = {
          deathTime = world.time() + existenceTimer
        },
        level = monster.level(),
        timeToLive = timeToLive
      }
    end

    world.sendEntityMessage("v-riftzonemanager-stagehand", "cleanUp", blocksToClearFG, blocksToClearBG, oresToClearFG, oresToClearBG, riftZoneData)
  end
end

function clearMatMods(radius)
  if not radius then return end
  radius = math.floor(radius)
  local ownPos = vec2.floor(mcontroller.position())

  for x = -radius, radius do
    for y = -radius, radius do
      local scanPos = vec2.add(ownPos, {x, y})

      local scanDist = world.magnitude(ownPos, scanPos)
      if scanDist <= radius then
        attemptRemoveMatMod(scanPos)
      end
    end
  end
end

function attemptPlaceMatMod(pos)
  if world.mod(pos, "foreground") == invisibleOre then
    world.placeMod(pos, "foreground", visibleOre)
  end
  if world.mod(pos, "background") == invisibleOre then
    world.placeMod(pos, "background", visibleOre)
  end
end

function attemptRemoveMatMod(pos)
  if world.mod(pos, "foreground") == visibleOre then
    world.placeMod(pos, "foreground", invisibleOre)
    placedOresFG[vVec2.iToString(pos)] = nil
  end
  if world.mod(pos, "background") == visibleOre then
    world.placeMod(pos, "background", invisibleOre)
    placedOresBG[vVec2.iToString(pos)] = nil
  end
end

function getBlocksToClear(blocks, layer)
  local blocksToClear = {}
  if not blocks then
    sb.logError("v-riftzone.lua: clearPlacedBlocks called with no blocks defined")
    return
  end
  for posString, _ in pairs(blocks) do
    local pos = vVec2.iFromString(posString)
    table.insert(blocksToClear, pos)
  end

  return blocksToClear

  -- world.damageTiles(blocksToClear, layer, mcontroller.position(), "blockish", INSTANT_BREAK_DAMAGE, 0)
end

function getOresToClear(ores, layer)
  local oresToClear = {}
  if not ores then
    sb.logError("v-riftzone.lua: clearPlacedOres called with no ores defined")
    return
  end
  local i = 0
  for posString, _ in pairs(ores) do
    local pos = vVec2.iFromString(posString)
    table.insert(oresToClear, pos)
    i = i + 1

    if i >= MAX_TILES_TO_DESTROY then
      break
    end
  end

  return oresToClear

  -- for _, tile in ipairs(oresToClear) do
  --   world.placeMod(tile, layer, invisibleOre)
  -- end
end

function closeToAPlayer(position)
  local players = world.players()
  for _, playerId in ipairs(players) do
    local playerPos = world.entityPosition(playerId)
    if playerPos then
      local region = rect.translate(playerProximityRegion, playerPos)
      if region[1] <= position[1] and position[1] <= region[3]
        and region[2] <= position[2] and position[2] <= region[4] then
        return true
      end
    end
  end

  return false
end

function makePerlinSource(paramName)
  local params = config.getParameter(paramName)
  params.seed = 0 + params.seedAdjust
  return sb.makePerlinSource(params)
end

function v_isRiftZone()
  return true
end

function v_killRiftZone()
  wasForceKilled = true
  existenceTimer = 0
end