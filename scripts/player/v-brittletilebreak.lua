require "/scripts/vec2.lua"
require "/scripts/util.lua"

require "/scripts/v-vec2.lua"

local destroyedMats  -- Tiles destroyed by brittleness. These must be tracked since world.damageTiles doesn't send tileBroken messages.
local destroyedMatsHash

local maxTilesDestroyed  -- Maximum number of tiles that are allowed to be processed in one tick.

local destroyChance
local groundlessDestroyChance

function init()
  destroyChance = 1 / 20
  -- destroyChance = 1 / 25
  groundlessDestroyChance = 1 / 2
  message.setHandler("v-brittletilebreak-tileBroken", handleBrokenTile)

  destroyedMats = {}
  destroyedMatsHash = {}

  maxTilesDestroyed = 30

  script.setUpdateDelta(3)
end

function update(dt)
  local oldDestroyedMats = copy(destroyedMats)
  destroyedMats = {}
  destroyedMatsHash = {}
  for i, pos in ipairs(oldDestroyedMats) do
    handleBrokenTile(nil, nil, pos, "foreground")

    if i > maxTilesDestroyed then
      break
    end
  end
end

function handleBrokenTile(_, _, pos, layer)
  local fgMatsToDestroy = {}
  local bgMatsToDestroy = {}

  for x = -2, 2 do
    for y = -2, 2 do
      local nextPos = vec2.add(pos, {x, y})

      if not destroyedMatsHash[vVec2.iToString(nextPos)] then
        if world.material(nextPos, "foreground") == "v-brittleice" then
          local shouldDestroy
          if world.material(vec2.add(nextPos, {0, -1}), "foreground") == false then
            shouldDestroy = math.random() <= groundlessDestroyChance
          else
            shouldDestroy = math.random() <= destroyChance
          end
          if shouldDestroy then
            table.insert(fgMatsToDestroy, nextPos)
            -- table.insert(bgMatsToDestroy, nextPos)
            table.insert(destroyedMats, nextPos)
            destroyedMatsHash[vVec2.iToString(nextPos)] = true
          end
        -- elseif world.material(nextPos, "background") == "v-brittleice" and math.random() <= destroyChance then
        --   table.insert(bgMatsToDestroy, nextPos)
        --   table.insert(destroyedMats, nextPos)
        --   destroyedMatsHash[vVec2.iToString(nextPos)] = true
        end
      end
    end
  end

  world.damageTiles(fgMatsToDestroy, "foreground", mcontroller.position(), "blockish", 2 ^ 32, 0)

  world.damageTiles(bgMatsToDestroy, "background", mcontroller.position(), "blockish", 2 ^ 32, 0)

  for _, pos in ipairs(fgMatsToDestroy) do
    world.spawnProjectile("v-icebreak", pos)
  end

  for _, pos in ipairs(bgMatsToDestroy) do
    world.spawnProjectile("v-icebreak", pos)
  end
end