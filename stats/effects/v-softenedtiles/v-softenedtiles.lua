require "/scripts/rect.lua"
require "/scripts/util.lua"
require "/scripts/vec2.lua"

require "/scripts/v-vec2.lua"

-- local destroyedMats  -- Tiles destroyed by brittleness. These must be tracked since world.damageTiles doesn't send tileBroken messages.

local excludedMats
local maxTilesDestroyed  -- Maximum number of tiles that are allowed to be processed in one tick.
local destroyChance
local groundlessDestroyChance

local destroyedMatsHash  -- Hash map of destroyed materials
local tilesDestroyed  -- Number of tiles destroyed in one tick

-- TODO: Rework this script to defer attempts at destroying tiles if more than maxTilesDestroyed tiles were destroyed in one tick.

function init()
  message.setHandler("v-softenedtiles-tileBroken", handleBrokenTile)

  excludedMats = {"v-voidstone", "v-voidstone2"}
  destroyChance = 1 / 5
  -- destroyChance = 1 / 20
  groundlessDestroyChance = 1 / 5
  maxTilesDestroyed = 60

  destroyedMatsHash = {}
  tilesDestroyed = 0
end

function update(dt)
  destroyedMatsHash = {}

  tilesDestroyed = 0
end

function handleBrokenTile(_, _, pos, layer)
  if tilesDestroyed >= maxTilesDestroyed then
    return
  end
  local fgMatsToDestroy = {}
  local bgMatsToDestroy = {}

  for x = -1, 1 do
    for y = -1, 1 do
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
  local mat = world.material(pos, "foreground")
  if mat and not contains(excludedMats, mat) then
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
  world.damageTiles(fgTilesToDestroy, "foreground", mcontroller.position(), "blockish", 20, 99, entity.id())

  for _, pos in ipairs(fgTilesToDestroy) do
    world.spawnProjectile("v-voidbreak", pos)
  end

  for _, pos in ipairs(bgTilesToDestroy) do
    world.spawnProjectile("v-voidbreak", pos)
  end
end