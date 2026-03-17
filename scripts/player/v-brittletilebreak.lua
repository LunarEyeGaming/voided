require "/scripts/rect.lua"
require "/scripts/util.lua"
require "/scripts/vec2.lua"

require "/scripts/v-vec2.lua"

-- local destroyedMats  -- Tiles destroyed by brittleness. These must be tracked since world.damageTiles doesn't send tileBroken messages.

local maxTilesDestroyed  -- Maximum number of tiles that are allowed to be processed in one tick.
local destroyChance
local groundlessDestroyChance
local collisionThreshold

local destroyedMatsHash  -- Hash map of destroyed materials
local tilesDestroyed  -- Number of tiles destroyed in one tick

-- TODO: Rework this script to defer attempts at destroying tiles if more than maxTilesDestroyed tiles were destroyed in one tick.

function init()
  message.setHandler("v-brittletilebreak-tileBroken", handleBrokenTile)

  destroyChance = 1 / 25
  -- destroyChance = 1 / 20
  groundlessDestroyChance = 1 / 2
  maxTilesDestroyed = 60
  collisionThreshold = 10

  destroyedMatsHash = {}
  tilesDestroyed = 0

  script.setUpdateDelta(2)
end

function update(dt)
  -- local oldDestroyedMats = copy(destroyedMats)
  -- destroyedMats = {}
  -- for i, pos in ipairs(oldDestroyedMats) do
  --   handleBrokenTile(nil, nil, pos, "foreground", true)

  --   if i > maxTilesDestroyed then
  --     break
  --   end
  -- end
  destroyedMatsHash = {}

  -- processCollisions()

  tilesDestroyed = 0
end

function processCollisions()
  local fgMatsToDestroy = {}

  local speed = vec2.mag(mcontroller.velocity())
  if speed >= collisionThreshold then
    local boundBox = rect.translate(mcontroller.boundBox(), mcontroller.position())

    boundBox = rect.pad(boundBox, 0.5)

    boundBox = {
      math.floor(boundBox[1]),
      math.floor(boundBox[2]),
      math.floor(boundBox[3]),
      math.floor(boundBox[4])
    }
    -- do
    --   local x = boundBox[1] - 1
    --   for y = boundBox[2], boundBox[4] do
    --     markTile({x, y}, fgMatsToDestroy)
    --   end
    -- end

    -- do
    --   local x = boundBox[3] + 1
    --   for y = boundBox[2], boundBox[4] do
    --     markTile({x, y}, fgMatsToDestroy)
    --   end
    -- end

    -- do
    --   local y = boundBox[2] - 1
    --   for x = boundBox[1], boundBox[3] do
    --     markTile({x, y}, fgMatsToDestroy)
    --   end
    -- end

    -- do
    --   local y = boundBox[4] + 1
    --   for x = boundBox[1], boundBox[3] do
    --     markTile({x, y}, fgMatsToDestroy)
    --   end
    -- end

    local chance = 1 - 1 / (speed - collisionThreshold + 1)

    for x = boundBox[1], boundBox[3] do
      for y = boundBox[2], boundBox[4] do
        markTile({x, y}, fgMatsToDestroy, chance)
      end
    end

    breakTiles(fgMatsToDestroy, {})
  end
end

function handleBrokenTile(_, _, pos, layer, test)
  if tilesDestroyed >= maxTilesDestroyed then
    return
  end
  local fgMatsToDestroy = {}
  local bgMatsToDestroy = {}

  if test ~= true then
    world.debugPoint(pos, "green")
  end

  for x = -2, 2 do
    for y = -2, 2 do
      local nextPos = vec2.add(pos, {x, y})

      if not destroyedMatsHash[vVec2.iToString(nextPos)] then
        local chance
        if world.material(vec2.add(pos, {0, -1}), "foreground") == false then
          chance = groundlessDestroyChance
        else
          chance = destroyChance
        end
        markTile(nextPos, fgMatsToDestroy, chance)
      end
    end
  end

  breakTiles(fgMatsToDestroy, bgMatsToDestroy)
end

function markTile(pos, fgMatsToDestroy, chance)
  if world.material(pos, "foreground") == "v-brittleice" then
    -- local shouldDestroy
    -- if world.material(vec2.add(pos, {0, -1}), "foreground") == false then
    --   shouldDestroy = math.random() <= groundlessDestroyChance
    -- else
    --   shouldDestroy = math.random() <= destroyChance
    -- end
    if math.random() <= chance then
      table.insert(fgMatsToDestroy, pos)
      -- table.insert(bgMatsToDestroy, pos)
      -- table.insert(destroyedMats, pos)
      tilesDestroyed = tilesDestroyed + 1
      destroyedMatsHash[vVec2.iToString(pos)] = true
    end
  end
end

function breakTiles(fgTilesToDestroy, bgTilesToDestroy)
  world.damageTiles(fgTilesToDestroy, "foreground", mcontroller.position(), "blockish", 2 ^ 32, 0, player.id())

  world.damageTiles(bgTilesToDestroy, "background", mcontroller.position(), "blockish", 2 ^ 32, 0, player.id())

  for _, pos in ipairs(fgTilesToDestroy) do
    world.spawnProjectile("v-icebreak", pos)
  end

  for _, pos in ipairs(bgTilesToDestroy) do
    world.spawnProjectile("v-icebreak", pos)
  end
end