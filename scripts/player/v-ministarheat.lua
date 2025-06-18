require "/scripts/interp.lua"
require "/scripts/vec2.lua"
require "/scripts/rect.lua"

require "/scripts/v-vec2.lua"
require "/scripts/v-ministarutil.lua"
require "/scripts/statuseffects/v-tickdamage.lua"
require "/scripts/v-time.lua"

-- Invalidate global height map segments with:
-- /entityeval for x = 0, world.size()[1] // 32 do world.setProperty("v-globalHeightMap." .. x .. ".0", nil) end

local maxDepth  -- Depth that heats up the slowest
local minDepth  -- Depth that heats up the fastest. Also the depth at which the player takes the most burn damage.

local burnDepth  -- Depth at which the player starts burning
local minBurnDamage
local maxBurnDamage
local tickTime

local tickDamage
local isActive
local celestialParamsFetched
local stagehandSpawned

local SECTOR_SIZE = 32

function init()
  script.setUpdateDelta(6)

  -- Do not run this script on planets that are not of type "v-ministar," except for the liquid scanner - that will keep
  -- running.
  if world.type() ~= "v-ministar" then
    isActive = false
    return
  end

  minBurnDamage = 1
  maxBurnDamage = 20
  tickTime = 0.5

  tickDamage = VTickDamage:new{ kind = "fire", amount = minBurnDamage, damageType = "IgnoresDef", interval = tickTime, source = player.id() }
  isActive = true
  celestialParamsFetched = false
  stagehandSpawned = false
end

function fetchCelestialParams()
  -- Initialize depth-related parameters
  local coords = getCelestialCoordinates()
  if coords then
    local celestialParams = celestial.visitableParameters(coords)
    if celestialParams then
      maxDepth = celestialParams.spaceLayer.layerMinHeight
      minDepth = celestialParams.surfaceLayer.primarySubRegion.oceanLiquidLevel
      burnDepth = (minDepth + maxDepth) / 2

      world.spawnStagehand(mcontroller.position(), "v-ministarheat", {
        minDepth = minDepth,
        maxDepth = maxDepth
      })

      celestialParamsFetched = true
    end
  else
    maxDepth = 2000
    minDepth = 1000
    -- minDepth = 990
    burnDepth = 1500

    celestialParamsFetched = true
  end
end

function update(dt)
  if isActive then
    -- Need to try fetching celestial parameters repeatedly because celestial.visitableParameters returns nil until
    -- shortly after the world is created (as opposed to immediately afterwards).
    if not celestialParamsFetched then
      fetchCelestialParams()
      return
    end

    -- Spawn stagehand after fetching celestial parameters.
    if celestialParamsFetched and not stagehandSpawned then
      world.spawnStagehand(mcontroller.position(), "v-ministarheat", {
        minDepth = minDepth,
        maxDepth = maxDepth
      })
      stagehandSpawned = true
      return
    end

    local pos = vec2.floor(mcontroller.position())

    -- Calculate solar flare boosts.
    local boosts = computeSolarFlareBoosts(pos[1], pos[1])

    local burnRatio = (1 - (pos[2] - minDepth) / (burnDepth - minDepth)) + boosts:get(pos[1])

    sb.setLogMap("burnRatio", "%s", burnRatio)

    if status.statPositive("v-ministarHeatTickMultiplier") then
      tickDamage.interval = tickTime * status.stat("v-ministarHeatTickMultiplier")
    end

    local multiplier = 1 - status.stat("v-ministarHeatResistance")

    -- If the player should be burned...
    if burnRatio > 0.0 and isExposedForeground() and multiplier > 0.0 then
      -- Update damage amount. It is a linear interpolation between maxBurnDamage and minBurnDamage, where damage grows as
      -- depth (aka y position) decreases.
      tickDamage.damageRequest.damage = interp.linear(burnRatio, minBurnDamage, maxBurnDamage) * multiplier
      tickDamage:update(dt)  -- Run the tickDamage object for one tick.
    else
      tickDamage:reset()
    end
  else
    if not stagehandSpawned then
      world.spawnStagehand(mcontroller.position(), "v-ministarheat")
      stagehandSpawned = true
    end
  end
end

---Returns celestial coordinates for the current world, if it is a celestial world. Returns `nil` otherwise.
---@return CelestialCoordinate?
function getCelestialCoordinates()
  local worldId = player.worldId()
  local first, last, x, y, z, planet = worldId:find("CelestialWorld:(%-?%d+):(%-?%d+):(%-?%d+):(%-?%d+)")
  if first then  -- Check if the string pattern matching succeeded.
    local satellite = worldId:match(":(%-?%d+)", last)  -- tonumber returns nil if satellite is nil.
    return {
      location = {tonumber(x), tonumber(y), tonumber(z)},
      planet = tonumber(planet),
      satellite = tonumber(satellite)
    }
  end
end

---Returns whether or not the player is exposed to the sunlight below provided a `heightMap`.
---@return boolean
function isExposedForeground()
  local pos = mcontroller.position()
  local boundBox = rect.translate(mcontroller.boundBox(), pos)
  local y = pos[2]

  local heightMap = getHeightMap(boundBox[1], boundBox[3])

  -- For each x across the current bounding box...
  for x = boundBox[1], boundBox[3] do
    -- local heightMapItem = heightMap.list[math.floor(x) - heightMap.startXPos + 1]
    local heightMapItem = heightMap:get(math.floor(world.xwrap(x)))

    if heightMapItem and minDepth < y and y < heightMapItem then
      return true
    end
  end

  return false
end

---Retrieves a section of the global height map and returns it.
---@return HeightMap
function getHeightMap(startX, endX)
  local startXSector = startX // SECTOR_SIZE
  local endXSector = endX // SECTOR_SIZE

  local heightMap = vMinistar.HeightMap:new()

  -- For each `xSector` from `startXSector` to `endXSector`...
  for xSector = startXSector, endXSector do
    local xSectorWrapped = math.floor(world.xwrap(xSector * SECTOR_SIZE) // SECTOR_SIZE)
    -- Get global height map section corresponding to `xSector`.
    local globalHeightMapSection = world.getProperty("v-globalHeightMap." .. xSectorWrapped) or {}

    -- Copy the section over to heightMap.
    for _, value in ipairs(globalHeightMapSection) do
      if startX <= value.x and value.x <= endX then
        heightMap:set(value.x, value.value)
      end
    end
  end

  return heightMap
end

---
---@param startX integer
---@param endX integer
---@return HeightMap
function computeSolarFlareBoosts(startX, endX)
  --[[
    Schema: {
      x: integer,  // Where the solar flare is located
      startTime: number,  // World time at which the solar flare started
      duration: number,  // How long the flare lasts.
      potency: number,  // Between 0 and 1. How potent the solar flare is.
      spread: number  // Controls the width of the solar flare.
    }[]
  ]]
  local solarFlares = world.getProperty("v-solarFlares") or {}

  local boosts = vMinistar.HeightMap:new()
  for x = startX, endX do
    boosts:set(x, 0)
  end

  for _, flare in ipairs(solarFlares) do
    local durationStdDev = flare.duration / 6
    local durationMean = flare.startTime + flare.duration / 2
    local timeMultiplier = normalDistribution(durationMean, durationStdDev, world.time())

    for x = startX, endX do
      boosts:set(x, boosts:get(x) + normalDistribution(flare.x, flare.spread / 3, x) * flare.potency * timeMultiplier)
    end
  end

  return boosts
end

function normalDistribution(mean, stdDev, x)
  return math.exp(-(x - mean) ^ 2 / (2 * stdDev ^ 2))
end