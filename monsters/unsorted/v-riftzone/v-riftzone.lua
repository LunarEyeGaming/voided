require "/scripts/vec2.lua"
require "/scripts/interp.lua"
require "/scripts/util.lua"
require "/scripts/v-animator.lua"

local scanRadius
local tileSofteningRadius
local invisibleOre
local visibleOre
local appearTime
local disappearTime
local disappearDelay
local timeToLive
local velocity

local prevPos
local prevRadius
local currentScanRadius
local currentTileSofteningRadius
local existenceTimer

local lightningController

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
  timeToLive = 300
  velocity = config.getParameter("velocity", {0, 0})

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

  monster.setDamageBar("None")
  state = FSM:new()
  state:set(states.postInit)
end

function update(dt)
  state:update(dt)

  lightningController:update(dt)

  updateMatMods(currentScanRadius)

  applyRiftDestabilization(currentScanRadius)
  applySoftenedTiles(currentTileSofteningRadius)

  crackleLightning(currentTileSofteningRadius)

  monster.setAnimationParameter("riftSize", currentScanRadius)

  -- world.loadRegion(rect.translate({-32, -32, 32, 32}, mcontroller.position()))
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

  for x = -radius, radius do
    for y = -radius, radius do
      local frontScanPos = vec2.add(ownPos, {x, y})

      local frontScanDist = world.magnitude(ownPos, frontScanPos)
      local frontScanDist2 = world.magnitude(prevPos, frontScanPos)
      if frontScanDist <= radius and frontScanDist2 > prevRadius then
        world.debugPoint(frontScanPos, "green")
        attemptPlaceMatMod(frontScanPos)
      end
    end
  end

  for x = -radius, radius do
    for y = -radius, radius do
      local backScanPos = vec2.add(prevPos, {x, y})

      local backScanDist = world.magnitude(ownPos, backScanPos)
      local backScanDist2 = world.magnitude(prevPos, backScanPos)
      if backScanDist > radius and backScanDist2 <= prevRadius then
        world.debugPoint(backScanPos, "green")
        attemptRemoveMatMod(backScanPos)
      end
    end
  end

  prevPos = ownPos
  prevRadius = radius
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
end

function attemptRemoveMatMod(pos)
  if world.mod(pos, "foreground") == visibleOre then
    world.placeMod(pos, "foreground", invisibleOre)
  end
end

function shouldDie()
  return g_shouldDieVar
end

function uninit()
  clearMatMods(scanRadius)

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