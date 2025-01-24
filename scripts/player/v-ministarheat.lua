require "/scripts/interp.lua"
require "/scripts/vec2.lua"
require "/scripts/rect.lua"

require "/scripts/v-vec2.lua"
require "/scripts/statuseffects/v-tickdamage.lua"

local cfg
local unmeltableMaterials

local heatMap
local heatTolerance
local maxDepth
local minDepth

local burnDepth
local minBurnDamage
local maxBurnDamage
local tickTime

local tickDamage

local checkMinX
local checkMaxX
local checkMinY
local checkMaxY

local collisionSet

local sunLiquidId

---@class HeatedTile
---@field pos Vec2I
---@field heatTolerance number
---@field heat number

function init()
  -- Do not run this script on planets that are not of type "v-ministar"
  if world.type() ~= "v-ministar" then
    script.setUpdateDelta(0)
    return
  end

  script.setUpdateDelta(6)

  cfg = root.assetJson("/v-matattributes.config:ministarHeatConfig")
  unmeltableMaterials = {}
  for _, material in ipairs(cfg.unmeltableMaterials) do
    unmeltableMaterials[material] = true
  end

  ---@type HeatedTile[]
  heatMap = {}
  heatTolerance = 20  -- Amount of time that must pass before the tile "burns" at starting depth
  maxDepth = 1980  -- Depth that heats up the slowest
  minDepth = 1000  -- Depth that heats up the fastest. Also the depth at which the player takes the most burn damage.
  undergroundDepthThreshold = 800 -- Depth that the player must be at to use the "underground" variants of some variables

  burnDepth = 1500  -- Depth at which the player starts burning
  minBurnDamage = 1
  maxBurnDamage = 20
  tickTime = 0.5

  tickDamage = VTickDamage:new{ kind = "fire", amount = minBurnDamage, damageType = "IgnoresDef", interval = tickTime, source = player.id() }

  checkMinX = -100
  checkMaxX = 100
  checkMinY = -100
  checkMaxY = 100

  collisionSet = {"Block", "Platform"}

  sunLiquidId = 2
end

function update(dt)
  local pos = vec2.floor(mcontroller.position())
  local affectedTiles = {}  -- hash map
  -- Maps horizontal positions relative to startXPos to collision heights.
  local heightMap = {startXPos = checkMinX + pos[1], list = {}, minHeight = minDepth}

  if pos[2] <= undergroundDepthThreshold then
    return
  end

  -- Variant of checkMinY that stops at minDepth; whether or not the value was capped.
  local cappedCheckMinY, checkMinYWasCapped
  if checkMinY + pos[2] < minDepth then
    cappedCheckMinY = minDepth
    checkMinYWasCapped = true
  else
    cappedCheckMinY = checkMinY + pos[2]
    checkMinYWasCapped = false
  end
  -- Generate a set of tiles that are heated right now.
  for x = checkMinX, checkMaxX do
    -- Proceed only if cappedCheckMinY is not actually capped or there is a liquid with ID sunLiquidId at the position
    -- directly below cappedCheckMinY.
    local shouldProceed = not checkMinYWasCapped
    if not shouldProceed then
      local liquid = world.liquidAt({x + pos[1], cappedCheckMinY - 1})
      if liquid and liquid[1] == sunLiquidId then
        shouldProceed = true
      end
    end

    if shouldProceed then
      local collidePointPair = world.lineTileCollisionPoint({x + pos[1], cappedCheckMinY}, {x + pos[1], checkMaxY + pos[2]}, collisionSet)
      if collidePointPair then
        local collidePoint = collidePointPair[1]
        world.debugPoint(collidePoint, "green")
        -- Round the tile's position to the nearest integer
        local collideTile = {math.floor(collidePoint[1] + 0.5), math.floor(collidePoint[2] + 0.5)}
        local collideTileStr = vVec2.iToString(collideTile)
        affectedTiles[collideTileStr] = true

        -- Add to height map.
        heightMap.list[x - checkMinX + 1] = {type = "partiallyObstructed", value = collideTile[2]}
      else
        heightMap.list[x - checkMinX + 1] = {type = "open"}
      end
    else
      heightMap.list[x - checkMinX + 1] = {type = "completelyObstructed"}
    end
  end

  -- Process existing entries.
  -- local tilesToDestroy = {}
  -- -- For each tile in the heatMap (iterated through backwards)...
  -- for i = #heatMap, 1, -1 do
  --   local tile = heatMap[i]

  --   local tilePosHash = vVec2.iToString(tile.pos)

  --   -- If the tile is in affectedTiles...
  --   if affectedTiles[tilePosHash] then
  --     -- Increase the heat amount.
  --     tile.heat = tile.heat + dt

  --     -- If the heat exceeds the tile's tolerance...
  --     if tile.heat > tile.heatTolerance then
  --       table.insert(tilesToDestroy, tile.pos)  -- Add to list of tiles to destroy.
  --       table.remove(heatMap, i)  -- Remove tile from heatMap.
  --     end

  --     -- Remove entry from affectedTiles to avoid excess inserts.
  --     affectedTiles[tilePosHash] = nil
  --   -- Otherwise, if the tile no longer exists...
  --   elseif not world.pointTileCollision(tile.pos, collisionSet) then
  --     table.remove(heatMap, i)
  --   else
  --     -- Decrease heat.
  --     tile.heat = tile.heat - dt

  --     -- If the heat drops below zero...
  --     if tile.heat <= 0 then
  --       table.remove(heatMap, i)  -- Remove tile from heatMap.
  --     end
  --   end
  -- end

  local tilesToDestroy = updateHeatMap(affectedTiles, dt)

  local sunProximityRatio = math.max(0, math.min((pos[2] - minDepth) / (maxDepth - minDepth), 1))
  -- Update heatMap for v-ministareffects.lua
  world.sendEntityMessage(player.id(), "v-ministareffects-updateBlocks", heatMap, heightMap, sunProximityRatio)

  -- Add affectedTiles to heatMap that are below the maxDepth value and are meltable.
  for tileHash, _ in pairs(affectedTiles) do
    local tile = vVec2.iFromString(tileHash)
    local material = world.material(tile, "foreground")

    -- Compute tolerance multiplier (tiles that are closer to minDepth have a lower heat tolerance). Capped at 0.
    local toleranceMultiplier = math.max(0, (tile[2] - minDepth) / (maxDepth - minDepth))

    -- If the tolerance multiplier is at most 1 and the tile is not unmeltable...
    if not unmeltableMaterials[material] and toleranceMultiplier <= 1.0 then
      -- Add to heat map.
      local tolerance = heatTolerance * toleranceMultiplier
      table.insert(heatMap, {pos = tile, heat = 0, heatTolerance = tolerance})
    end
  end

  -- Destroy tiles.
  world.damageTiles(tilesToDestroy, "foreground", mcontroller.position(), "blockish", 2 ^ 32 - 1, 0)

  -- If the player should be burned...
  if pos[2] <= burnDepth and isExposedForeground() and isExposedBackground() then
    -- Update damage amount. It is a linear interpolation between maxBurnDamage and minBurnDamage, where damage grows as
    -- depth (aka y position) decreases.
    tickDamage.damageRequest.damage = interp.linear((pos[2] - minDepth) / (burnDepth - minDepth), maxBurnDamage, minBurnDamage)
    tickDamage:update(dt)  -- Run the tickDamage object for one tick.
  else
    tickDamage:reset()
  end
end

---Given a hash set of affectedTiles, updates `heatMap`. Each entry in `heatMap` that is also present in `affectedTiles`
---has its heat increased (decreased otherwise). Returns a list of tiles to destroy. Note: This also updates
---`affectedTiles` to exclude what was found in `heatMap`.
---@param affectedTiles table<string, boolean>
---@param dt number
---@return Vec2I[]
function updateHeatMap(affectedTiles, dt)
  local tilesToDestroy = {}
  -- For each tile in the heatMap (iterated through backwards)...
  for i = #heatMap, 1, -1 do
    local tile = heatMap[i]

    local tilePosHash = vVec2.iToString(tile.pos)

    -- If the tile is in affectedTiles...
    if affectedTiles[tilePosHash] then
      -- Increase the heat amount.
      tile.heat = tile.heat + dt

      -- If the heat exceeds the tile's tolerance...
      if tile.heat > tile.heatTolerance then
        table.insert(tilesToDestroy, tile.pos)  -- Add to list of tiles to destroy.
        table.remove(heatMap, i)  -- Remove tile from heatMap.
      end

      -- Remove entry from affectedTiles to avoid excess inserts.
      affectedTiles[tilePosHash] = nil
    -- Otherwise, if the tile no longer exists...
    elseif not world.pointTileCollision(tile.pos, collisionSet) then
      table.remove(heatMap, i)
    else
      -- Decrease heat.
      tile.heat = tile.heat - dt

      -- If the heat drops below zero...
      if tile.heat <= 0 then
        table.remove(heatMap, i)  -- Remove tile from heatMap.
      end
    end
  end

  return tilesToDestroy
end

function isExposedBackground()
  local boundBox = mcontroller.boundBox()
  local ownPos = mcontroller.position()
  for x = boundBox[1], boundBox[3] do
    for y = boundBox[2], boundBox[4] do
      if not world.material(vec2.add(ownPos, {x, y}), "background") then
        return true
      end
    end
  end

  return false
end

function isExposedForeground()
  local boundBox = rect.translate(mcontroller.boundBox(), mcontroller.position())
  local y = mcontroller.position()[2]

  -- If there is at least one tile below the player without collision, return true. Return false otherwise.
  for x = boundBox[1], boundBox[3] do
    if not world.lineTileCollision({x, y}, {x, math.max(minDepth, y + checkMinY)}, {"Block"}) then
      return true
    end
  end

  return false
end