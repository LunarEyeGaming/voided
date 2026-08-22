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
local bufferedTilesToDestroy  -- List of tiles to destroy, partitioned such that each sub-list has at most maxTilesDestroyed tiles.
local nextBuffer

-- TODO: Rework this script to defer attempts at destroying tiles if more than maxTilesDestroyed tiles were destroyed in one tick.

function init()
  message.setHandler("v-brittletilebreak-tileBroken", handleBrokenTile)

  destroyChance = 1 / 25
  -- destroyChance = 1 / 20
  groundlessDestroyChance = 1 / 2
  maxTilesDestroyed = 30
  collisionThreshold = 10

  destroyedMatsHash = {}
  tilesDestroyed = 0
  bufferedTilesToDestroy = {}
  nextBuffer = {}

  script.setUpdateDelta(2)
end

function update(dt)
  -- Take one list from the queue of groups to process. Empty out nextBuffer if there are no more lists to take.
  local bufferToProcess = table.remove(bufferedTilesToDestroy, 1)
  if not bufferToProcess then
    bufferToProcess = nextBuffer
    nextBuffer = {}
  end

  breakTiles(bufferToProcess)

  destroyedMatsHash = {}

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

    -- Chance is greater than zero for speeds above the collisionThreshold and increases for higher speeds.
    local chance = 1 - 1 / (speed - collisionThreshold + 1)

    for x = boundBox[1], boundBox[3] do
      for y = boundBox[2], boundBox[4] do
        markTile({x, y}, fgMatsToDestroy, chance)
      end
    end
  end
end

function handleBrokenTile(_, _, pos, layer)
  local fgMatsToDestroy = {}

  -- Pick nearby tiles to destroy.
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
end

function markTile(pos, fgMatsToDestroy, chance)
  if world.material(pos, "foreground") == "v-brittleice" then
    if math.random() <= chance then
      -- Add to nextBuffer. If the buffer is full, add to bufferedTilesToDestroy and reset.
      table.insert(nextBuffer, pos)
      if #nextBuffer > maxTilesDestroyed then
        table.insert(bufferedTilesToDestroy, nextBuffer)
        nextBuffer = {}
      end

      tilesDestroyed = tilesDestroyed + 1
      destroyedMatsHash[vVec2.iToString(pos)] = true
    end
  end
end

function breakTiles(fgTilesToDestroy)
  if #fgTilesToDestroy == 0 then
    return
  end

  world.damageTiles(fgTilesToDestroy, "foreground", mcontroller.position(), "blockish", 5, 99, player.id())

  for _, pos in ipairs(fgTilesToDestroy) do
    world.spawnProjectile("v-icebreak", pos)
  end
end