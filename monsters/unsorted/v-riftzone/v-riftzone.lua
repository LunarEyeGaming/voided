require "/scripts/vec2.lua"
require "/scripts/interp.lua"
require "/scripts/util.lua"

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
local velocity
local playerProximityRegion

local prevPos
local prevRadius
local currentScanRadius
local currentTileSofteningRadius
local existenceTimer

local lightningController
local perlinSource
local orePerlinSource
local oreBGPerlinSource
local placedBlocks
local placedBlocksBG
local placedAssists
local blocksToPlace
local oresToPlace
local bgOresToPlace

local state

--[[
  Possible ways of making it persist across unloaded regions:
  * Persistent + storage - nope. Then it won't move until the player loads it.
  * Store state data in world.setProperty, then have the client retrieve it.
    *
]]

function init()
  scanRadius = 35
  tileSofteningRadius = 80
  monster.setAnimationParameter("riftSize", 0)
  invisibleOre = "v-nulliuminvisible"
  visibleOre = "v-nulliumvisible"
  appearTime = 7
  disappearTime = 7
  disappearDelay = 3
  timeToLive = config.getParameter("timeToLive", 300)
  velocity = config.getParameter("velocity", {0, 0})
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
    frequency = 0.05
  })
  orePerlinSource = sb.makePerlinSource({
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
  placedBlocks = {}
  placedBlocksBG = {}
  placedAssists = {}

  monster.setDamageBar("None")
  state = FSM:new()
  state:set(states.postInit)
end

function update(dt)
  state:update(dt)

  lightningController:update(dt)

  -- Suppress updates to tiles if too far away from any players to prevent loading chunks, causing a chain reaction of
  -- rift zones loading into existence.
  if closeToAPlayer(mcontroller.position()) then
    updateMatMods(currentScanRadius)
  end

  applyRiftDestabilization(currentScanRadius)
  applySoftenedTiles(currentTileSofteningRadius)

  crackleLightning(currentTileSofteningRadius)

  perlinNoiseTest(currentScanRadius)

  monster.setAnimationParameter("riftSize", currentScanRadius + 1)

  local placedBlocksCount = 0
  local placedBlocksBGCount = 0
  local placedAssistsCount = 0
  for _, _ in pairs(placedBlocks) do
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
  clearPlacedBlocks(placedBlocks, "foreground")
  clearPlacedBlocks(placedBlocksBG, "background")

  if g_shouldDieVar then
    return
  end

  local riftZones = world.getProperty("v-riftZones") or jarray()
  table.insert(riftZones, {
    position = mcontroller.position(),
    velocity = velocity,
    stateData = {
      deathTime = world.time() + existenceTimer
    }
  })
  world.setProperty("v-riftZones", riftZones)
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

  while existenceTimer > 0 do
    mcontroller.setVelocity(velocity)

    existenceTimer = existenceTimer - script.updateDt()

    coroutine.yield()
  end

  state:set(states.disappear)
end

function states.disappear()
  animator.playSound("close")

  util.wait(disappearDelay)

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

  -- The script should stop running within the next tick or two. This just ensures the coroutine doesn't die prematurely
  -- and cause an error.
  while true do
    coroutine.yield()
  end
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

function applyRiftDestabilization(radius)
  local queried = world.entityQuery(mcontroller.position(), radius, {
    includedTypes = {"creature"},
    withoutEntityId = entity.id()
  })

  for _, entityId in ipairs(queried) do
    world.sendEntityMessage(entityId, "applyStatusEffect", "v-riftdestabilization")
  end
end

function applySoftenedTiles(radius)
  local queried = world.entityQuery(mcontroller.position(), radius, {
    includedTypes = {"player"},
    withoutEntityId = entity.id()
  })

  for _, entityId in ipairs(queried) do
    world.sendEntityMessage(entityId, "applyStatusEffect", "v-softenedtiles")
  end
end

function updateMatMods(radius)
  radius = math.floor(radius)
  local ownPos = vec2.floor(mcontroller.position())
  world.debugPoint(ownPos, "green")

  placeOres()

  placeBlocks()

  for x = -radius, radius do
    for y = -radius, radius do
      local frontScanPos = vec2.add(ownPos, {x, y})

      local frontScanDist = world.magnitude(ownPos, frontScanPos)
      local frontScanDist2 = world.magnitude(prevPos, frontScanPos)
      if frontScanDist <= radius and frontScanDist2 > prevRadius then
        world.debugPoint(frontScanPos, "green")
        attemptPlaceMatMod(frontScanPos)
        if not world.material(frontScanPos, "foreground") and shouldPlaceBlock(frontScanPos) then
          table.insert(blocksToPlace, frontScanPos)
          placedBlocks[vVec2.iToString(frontScanPos)] = true
          placedBlocksBG[vVec2.iToString(frontScanPos)] = true
        end
      end
    end
  end

  placeAssists()

  local blocksToRemove = {}
  local blocksToRemoveBG = {}

  for x = -radius, radius do
    for y = -radius, radius do
      local backScanPos = vec2.add(prevPos, {x, y})

      local backScanDist = world.magnitude(ownPos, backScanPos)
      local backScanDist2 = world.magnitude(prevPos, backScanPos)
      if backScanDist > radius and backScanDist2 <= prevRadius then
        world.debugPoint(backScanPos, "green")
        attemptRemoveMatMod(backScanPos)
        if placedBlocks[vVec2.iToString(backScanPos)] then
          table.insert(blocksToRemove, backScanPos)
          placedBlocks[vVec2.iToString(backScanPos)] = nil
        end
        if placedBlocksBG[vVec2.iToString(backScanPos)] then
          table.insert(blocksToRemoveBG, backScanPos)
          placedBlocksBG[vVec2.iToString(backScanPos)] = nil
        end
      end
    end
  end

  world.damageTiles(blocksToRemove, "foreground", mcontroller.position(), "blockish", 2 ^ 32, 0)
  world.damageTiles(blocksToRemoveBG, "background", mcontroller.position(), "blockish", 2 ^ 32, 0)

  prevPos = ownPos
  prevRadius = radius
end

function placeOres()
  if oresToPlace then
    for _, block in ipairs(oresToPlace) do
      world.placeMod(block, "foreground", visibleOre)
    end
  end

  oresToPlace = {}

  if bgOresToPlace then
    for _, block in ipairs(bgOresToPlace) do
      world.placeMod(block, "background", visibleOre)
    end
  end

  bgOresToPlace = {}
end

function placeBlocks()
  -- Block placement is deferred to the next tick to wait for place assists to spawn.
  if blocksToPlace then
    -- Sort in descending order by y value
    table.sort(blocksToPlace, function(a, b) return a[2] > b[2] end)

    for _, block in ipairs(blocksToPlace) do
      local blockString = vVec2.iToString(block)
      if not world.placeMaterial(block, "foreground", "v-voidstone2") and not placedAssists[blockString] then
        placedBlocks[blockString] = nil
      end
      if not world.placeMaterial(block, "background", "v-voidstone2") then
        placedBlocksBG[blockString] = nil
      end
      if orePerlinSource:get(block[1], block[2]) > 0 then
        table.insert(oresToPlace, block)
      end
      if oreBGPerlinSource:get(block[1], block[2]) > 0 then
        table.insert(bgOresToPlace, block)
      end
    end
  end

  blocksToPlace = {}
end

function placeAssists()
  local maxYPositions = {}

  placedAssists = {}

  for _, block in ipairs(blocksToPlace) do
    if not maxYPositions[block[1]] then
      maxYPositions[block[1]] = -math.huge
    end

    maxYPositions[block[1]] = math.max(maxYPositions[block[1]], block[2])
  end

  for x, y in pairs(maxYPositions) do
    local placedObject = world.placeObject("terra_placeassist", {x, y + 1} --[[@as Vec2I]], nil, {
      material = "v-voidstone2",
      overlap = true,
      layer = "foreground"
    })
    if placedObject then
      placedAssists[vVec2.iToString({x, y})] = true
      -- placedBlocks[vVec2.iToString({x, y})] = true
    end
  end
end

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
end

function removeBlock(pos)

end

function perlinNoiseTest(radius)
  local ownPos = vec2.floor(mcontroller.position())

  for x = -radius, radius do
    for y = -radius, radius do
      local pos = vec2.add(ownPos, {x, y})

    end
  end
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