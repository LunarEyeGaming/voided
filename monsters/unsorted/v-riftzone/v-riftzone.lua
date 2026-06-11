require "/scripts/vec2.lua"
require "/scripts/interp.lua"
require "/scripts/util.lua"

require "/scripts/v-attack.lua"
require "/scripts/v-animator.lua"
require "/scripts/v-vec2.lua"

local scanRadius
local tileSofteningRadius
local invisibleOre
local visibleOre
local appearTime
local disappearTime
local disappearDelay
local timeToLive
local initialVelocity
local velocity
local rotationPeriod
local playerProximityRegion
local meteorPower

local prevPos
local prevRadius
local currentScanRadius
local currentTileSofteningRadius
local existenceTimer

local lightningController
local perlinSource
local oreFGPerlinSource
local oreBGPerlinSource
local placedBlocksFG
local placedBlocksBG
local placedAssists
local fgBlocksToPlace
local bgBlocksToPlace
local fgOresToPlace
local bgOresToPlace
local frontScanPositions
local backScanPositions
local rotationTimer

local weatherFunction

local state

local deferredTasks

function init()
  sb.logInfo("%s: init called", entity.id())
  scanRadius = 35
  tileSofteningRadius = 80
  monster.setAnimationParameter("riftSize", 0)
  invisibleOre = "v-nulliuminvisible"
  visibleOre = "v-nulliumvisible"
  appearTime = 7
  disappearTime = 7
  disappearDelay = 3
  timeToLive = config.getParameter("timeToLive", 300)
  initialVelocity = config.getParameter("velocity", {0, 0})
  velocity = initialVelocity
  rotationPeriod = 120
  playerProximityRegion = {-100, -100, 100, 100}

  prevPos = vec2.floor(mcontroller.position())
  prevRadius = 0
  currentScanRadius = 0
  currentTileSofteningRadius = 0
  existenceTimer = timeToLive
  g_shouldDieVar = false

  local cfg = config.getParameter("lightningConfig", {})

  lightningController = vAnimator.LightningController:new{
    cfg = cfg.baseConfig,
    startC = cfg.startColor,
    endC = cfg.endColor,
    dur = cfg.duration,
    animateManually = false,
    startOC = cfg.startOutlineColor,
    endOC = cfg.endOutlineColor,
  }
  perlinSource = sb.makePerlinSource({
    seed = 0,
    octaves = 3,
    type = "perlin",
    frequency = 0.025
  })
  oreFGPerlinSource = sb.makePerlinSource({
    seed = 1,
    type = "perlin",
    frequency = 0.1,
    bias = -0.35
  })
  oreBGPerlinSource = sb.makePerlinSource({
    seed = 2,
    type = "perlin",
    frequency = 0.1,
    bias = -0.4
  })
  placedBlocksFG = {}
  placedBlocksBG = {}
  placedAssists = {}
  meteorPower = 10
  rotationTimer = 0

  local weatherName = world.getProperty("v-riftZoneWeather") or "destabilization"
  if weatherName == "meteors" then
    weatherFunction = function()
      spawnMeteors(currentScanRadius)
    end
  elseif weatherName == "gravispheres" then
    weatherFunction = function()
      spawnGravispheres()
    end
  elseif weatherName == "destabilization" then
    weatherFunction = function()
      applyEffect("v-riftdestabilization", currentScanRadius)
    end
  else
    error(string.format("Unknown rift zone weather: %s", weatherName))
  end

  monster.setDamageBar("None")
  state = FSM:new()
  state:set(states.postInit)

  deferredTasks = {}
end

function update(dt)
  callDeferredTasks()

  state:update(dt)

  lightningController:update(dt)

  -- Suppress updates to tiles if too far away from any players to prevent loading chunks, causing a chain reaction of
  -- rift zones loading into existence.
  if closeToAPlayer(mcontroller.position()) then
    updateDeltaScans(currentScanRadius)
    updateMaterials(currentScanRadius)
    updateWeather(dt)
  end

  applyEffect("v-softenedtiles", currentTileSofteningRadius)
  applyEffect("v-rifteffects", currentScanRadius)

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
  clearMatMods(scanRadius)
  clearPlacedBlocks(placedBlocksFG, "foreground")
  clearPlacedBlocks(placedBlocksBG, "background")

  if not g_shouldDieVar then
    local riftZones = world.getProperty("v-riftZones") or jarray()
    table.insert(riftZones, {
      position = mcontroller.position(),
      velocity = velocity,
      stateData = {
        deathTime = world.time() + existenceTimer
      },
      level = monster.level(),
      timeToLive = timeToLive
    })
    world.setProperty("v-riftZones", riftZones)
  end
end

states = {}

function states.postInit()
  for _ = 1, 2 do
    coroutine.yield()
  end

  notifyRiftZoneSpawned()

  setExistenceTimer()

  if existenceTimer <= -disappearTime then
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

  local timer = 0
  while timer < appearTime do
    currentScanRadius = interp.sin(timer / appearTime, 0, scanRadius)
    currentTileSofteningRadius = interp.sin(timer / appearTime, 0, tileSofteningRadius)

    timer = timer + script.updateDt()

    coroutine.yield()
  end

  state:set(states.move)
end

function states.move()
  currentScanRadius = scanRadius
  currentTileSofteningRadius = tileSofteningRadius

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

  util.wait(disappearDelay)

  mcontroller.setVelocity({0, 0})

  local timer = disappearTime
  while timer > 0 do
    currentScanRadius = interp.sin(timer / disappearTime, 0, scanRadius)
    currentTileSofteningRadius = interp.sin(timer / disappearTime, 0, tileSofteningRadius)

    timer = timer - script.updateDt()

    coroutine.yield()
  end

  currentScanRadius = 0
  currentTileSofteningRadius = 0

  state:set(states.die)
end

function states.die()
  g_shouldDieVar = true

  if math.random() < 0.70 then
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
  if math.random() < 0.1 then
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

function spawnMeteors(spawnRadius)
  if math.random() < 0.1 then
    local appearDelay = 0.75
    local speed = 30
    local spawnAngle = vVec2.randomAngle(math.pi / 2, math.pi / 4)

    local appearPoint = vec2.withAngle(spawnAngle, spawnRadius)
    local spawnDirection = vec2.withAngle(vVec2.randomAngle(-math.pi / 2, math.pi / 8))
    local spawnPoint = vec2.add(appearPoint, vec2.mul(spawnDirection, -speed * appearDelay))
    local spawnPointWorld = vec2.add(mcontroller.position(), spawnPoint)
    world.spawnProjectile("v-riftzonemeteorsound", spawnPointWorld, entity.id(), spawnDirection, false, {
      power = vAttack.scaledPower(meteorPower or 10),
      speed = speed,
      appearDelay = appearDelay
    })
  end
end

function spawnGravispheres()
  for _, frontScanPos in ipairs(frontScanPositions) do
    if math.random() < 0.001 then
      world.spawnProjectile("v-gravispherewindup", frontScanPos, entity.id(), {1, 0}, false, {
        power = vAttack.scaledPower(meteorPower or 10)
      })
    end
  end
end

function applyEffect(effectName, radius)
  local queried = world.entityQuery(mcontroller.position(), radius, {
    includedTypes = {"player"},
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

  frontScanPositions = {}
  backScanPositions = {}

  for x = -radius, radius do
    for y = -radius, radius do
      local frontScanPos = vec2.add(ownPos, {x, y})

      local frontScanDist = world.magnitude(ownPos, frontScanPos)
      local frontScanDist2 = world.magnitude(prevPos, frontScanPos)
      if frontScanDist <= radius and frontScanDist2 > prevRadius then
        table.insert(frontScanPositions, frontScanPos)
      end
    end
  end

  for x = -radius, radius do
    for y = -radius, radius do
      local backScanPos = vec2.add(prevPos, {x, y})

      local backScanDist = world.magnitude(ownPos, backScanPos)
      local backScanDist2 = world.magnitude(prevPos, backScanPos)
      if backScanDist > radius and backScanDist2 <= prevRadius then
        table.insert(backScanPositions, backScanPos)
      end
    end
  end

  prevPos = ownPos
  prevRadius = radius
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
      table.insert(blocksToPlaceFG, {pos = frontScanPos, material = "v-voidstone2"})
      table.insert(blocksToPlaceBG, {pos = frontScanPos, material = "v-voidstone2"})
      if oreFGPerlinSource:get(frontScanPos[1], frontScanPos[2]) > 0 then
        table.insert(oresToPlaceFG, frontScanPos)
      end
      if oreBGPerlinSource:get(frontScanPos[1], frontScanPos[2]) > 0 then
        table.insert(oresToPlaceBG, frontScanPos)
      end
    else
      table.insert(blocksToPlaceBG, {pos = frontScanPos, material = "lightblocker"})
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

  world.damageTiles(blocksToRemove, "foreground", mcontroller.position(), "blockish", 2 ^ 32, 0)
  world.damageTiles(blocksToRemoveBG, "background", mcontroller.position(), "blockish", 2 ^ 32, 0)

  prevPos = ownPos
  prevRadius = radius
end

function placeOres(fg, bg)
  if fg then
    for _, block in ipairs(fg) do
      world.placeMod(block, "foreground", visibleOre)
    end
  end

  if bg then
    for _, block in ipairs(bg) do
      world.placeMod(block, "background", visibleOre)
    end
  end
end

-- function placeBlocks()
--   -- Block placement is deferred to the next tick to wait for place assists to spawn.
--   if fgBlocksToPlace then
--     -- Sort in descending order by y value
--     table.sort(fgBlocksToPlace, function(a, b) return a[2] > b[2] end)

--     for _, block in ipairs(fgBlocksToPlace) do
--       local blockString = vVec2.iToString(block)
--       if not world.placeMaterial(block, "foreground", "v-voidstone2") and not placedAssists[blockString] then
--         placedBlocksFG[blockString] = nil
--       end
--       if not world.placeMaterial(block, "background", "v-voidstone2") then
--         placedBlocksBG[blockString] = nil
--       end
--       if oreFGPerlinSource:get(block[1], block[2]) > 0 then
--         table.insert(fgOresToPlace, block)
--       end
--       if oreBGPerlinSource:get(block[1], block[2]) > 0 then
--         table.insert(bgOresToPlace, block)
--       end
--     end
--   end

--   fgBlocksToPlace = {}
-- end

-- function placeAssists()
--   local maxYPositions = {}

--   placedAssists = {}

--   for _, block in ipairs(fgBlocksToPlace) do
--     if not maxYPositions[block[1]] then
--       maxYPositions[block[1]] = -math.huge
--     end

--     maxYPositions[block[1]] = math.max(maxYPositions[block[1]], block[2])
--   end

--   for x, y in pairs(maxYPositions) do
--     local placedObject = world.placeObject("terra_placeassist", {x, y + 1} --[[@as Vec2I]], nil, {
--       material = "v-voidstone2",
--       overlap = true,
--       layer = "foreground"
--     })
--     if placedObject then
--       placedAssists[vVec2.iToString({x, y})] = true
--       -- placedBlocks[vVec2.iToString({x, y})] = true
--     end
--   end
-- end

function shouldPlaceBlock(pos)
  local z = perlinSource:get(pos[1], pos[2])
  if 0.1 <= z and z <= 0.2 then
    z = 1
  else
    z = 0
  end
  -- local color = vAnimator.lerpColorRGB(z, {0, 0, 0}, {255, 255, 255})
  -- world.debugPoint(pos, "#" .. vAnimator.colorToString(color))

  return z > 0
  -- return pos[2] % 2 == 0
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
      placedBlocks[vVec2.iToString(block.pos)] = true
    end
  end

  -- Defer to next update
  table.insert(deferredTasks, function()
    for _, block in ipairs(blocksToPlace) do
      if not placedBlocks[vVec2.iToString(block.pos)] then
        local success = world.placeMaterial(block.pos, currentLayer, block.material)
        if success then
          placedBlocks[vVec2.iToString(block.pos)] = true
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
  end
  if world.mod(pos, "background") == visibleOre then
    world.placeMod(pos, "background", invisibleOre)
  end
end

function clearPlacedBlocks(blocks, layer)
  local blocksToClear = {}
  if not blocks then
    sb.logError("v-riftzone.lua: clearPlacedBlocks called with no blocks defined")
    return
  end
  for posString, _ in pairs(blocks) do
    local pos = vVec2.iFromString(posString)
    table.insert(blocksToClear, pos)
  end

  if #blocksToClear > 1000 then
    blocksToClear[1001] = nil
  end

  world.damageTiles(blocksToClear, layer, mcontroller.position(), "blockish", 2 ^ 32, 0)
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