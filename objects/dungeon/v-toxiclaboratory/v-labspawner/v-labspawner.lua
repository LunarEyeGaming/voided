require "/scripts/util.lua"
require "/scripts/vec2.lua"
require "/scripts/rect.lua"
require "/objects/wired/v-monsterwavespawner/v-monsterwavespawner.lua"
require "/scripts/v-animator.lua"

local openAnimationDuration
local openingCloseDelay

local spawnerProjectileType

local gracePeriod
local gracePeriodStartPaletteSwap  -- The starting colors to swap. The values are represented by tables for quicker calculations
local gracePeriodEndPaletteSwap  -- The ending colors to swap. The values are represented by tables for quicker calculations
local gracePeriodPaletteSwapTime  -- The amount of time it takes to transition to the swapped colors.
local gracePeriodTimer

local spawnerProjectilePosition

local oldInit = init or function() end

function init()
  oldInit()

  openAnimationDuration = config.getParameter("openAnimationDuration", 0.2)
  openingCloseDelay = config.getParameter("openingCloseDelay", 0.25)

  spawnerProjectileType = config.getParameter("spawnerProjectileType", "v-cityspawnerorb")

  gracePeriod = config.getParameter("gracePeriod")

  gracePeriodStartPaletteSwap = {}
  gracePeriodEndPaletteSwap = {}

  for oldColor, newColor in pairs(config.getParameter("gracePeriodPaletteSwap", {})) do
    gracePeriodStartPaletteSwap[oldColor] = vAnimator.colorOfString(newColor)
    gracePeriodEndPaletteSwap[oldColor] = vAnimator.colorOfString(oldColor)
  end

  gracePeriodPaletteSwapTime = config.getParameter("gracePeriodPaletteSwapTime")

  local spawnerProjectileOffset = config.getParameter("spawnerProjectileOffset", {0, 0})
  spawnerProjectilePosition = vec2.add(object.position(), spawnerProjectileOffset)
end

-- HOOK OVERRIDES. See v-monsterwavespawner.lua documentation for more details.
function onLoad()
  animator.setGlobalTag("numWaves", tostring(#storage.waves))
  animator.setGlobalTag("numCompletedWaves", "0")
  animator.setAnimationState("waveStatus", "inactive")
end

function onGracePeriodStart()
  gracePeriodTimer = 0
end

function onGracePeriodTick(dt)
  gracePeriodTimer = gracePeriodTimer + dt

  -- Spend gracePeriodPaletteSwapTime transitioning to the new colors
  if gracePeriodTimer < gracePeriodPaletteSwapTime then
    local newPaletteSwap = {}

    for oldColor, newColorT in pairs(gracePeriodStartPaletteSwap) do
      -- Calculate progress ratio
      local progress = gracePeriodTimer / gracePeriodPaletteSwapTime

      -- Get old color table
      local oldColorT = gracePeriodEndPaletteSwap[oldColor]

      -- Lerp to new color
      newPaletteSwap[oldColor] = vAnimator.stringOfColor(vAnimator.lerpColorRGB(progress, oldColorT, newColorT))
    end

    applyPaletteSwap(newPaletteSwap)
  else  -- Spend remaining time transitioning to the old colors.
    local newPaletteSwap = {}

    for oldColor, newColorT in pairs(gracePeriodStartPaletteSwap) do
      -- Calculate progress ratio. Account for the delay in the calculations.
      local progress = (gracePeriodTimer - gracePeriodPaletteSwapTime) / (gracePeriod - gracePeriodPaletteSwapTime)

      -- Get old color table
      local oldColorT = gracePeriodEndPaletteSwap[oldColor]

      -- Lerp back to old color
      newPaletteSwap[oldColor] = vAnimator.stringOfColor(vAnimator.lerpColorRGB(progress, newColorT, oldColorT))
    end

    applyPaletteSwap(newPaletteSwap)
  end
end

function onWavesStart()
  -- Clear palette swap
  animator.setPartTag("base", "paletteSwap", "")
end

function onWaveEnd(waveNum)
  animator.setGlobalTag("numCompletedWaves", waveNum)
  animator.setAnimationState("waveStatus", "inactive")
end

function onDeactivation()
  animator.setGlobalTag("numWaves", tostring(#storage.waves))
  animator.setGlobalTag("numCompletedWaves", tostring(#storage.waves))
end

--[[
  Spawns the monsters in the current wave. Waits until all projectiles spawned die, and the resulting monster IDs are
  populated in the returned list.

  waveSpawners: A table with the following schema:
    {
      {
        String type: the monster type to spawn
        Vec2F position: the position to spawn the monster at
        Json parameters: the parameters to override
      }
    }
  returns: a list of the IDs of the monsters spawned
]]
function spawnWave(waveSpawners)
  animator.setAnimationState("waveStatus", "transition")

  local monsterIds = {}  -- Gets populated by the message handler

  -- If the list of spawners is not empty...
  if #waveSpawners > 0 then
    local projectileIds = {}

    animator.setAnimationState("opening", "opening")
    animator.playSound("open")

    util.wait(openAnimationDuration)

    -- NOTE: Very slim chance that this will result in a memory leak.
    message.setHandler("v-monsterSpawned", function(_, _, monsterId)
      table.insert(monsterIds, monsterId)
    end)

    -- For each monster in the current wave...
    for _, monster in ipairs(waveSpawners) do
      animator.playSound("spawn")

      -- Spawn a projectile that will spawn the monster
      local projectileId = world.spawnProjectile(spawnerProjectileType, spawnerProjectilePosition, entity.id(), {1, 0},
          false, {targetPosition = monster.position, monsterType = monster.type, monsterParameters = monster.parameters})

      table.insert(projectileIds, projectileId)

      coroutine.yield()
    end

    util.wait(openingCloseDelay)

    animator.setAnimationState("opening", "closing")
    animator.playSound("close")

    -- While at least one of the spawned projectiles is still alive...
    while #projectileIds > 0 do
      -- Filter out projectiles that died
      projectileIds = util.filter(projectileIds, function(id) return world.entityExists(id) end)

      coroutine.yield()
    end
  end

  return monsterIds
end

-- HELPER FUNCTIONS
--[[
  Applies a palette swap `paletteSwap` (a `?replace` directive) to the part "base".
]]
function applyPaletteSwap(paletteSwap)
  local directive = "?replace"

  for oldColor, newColor in pairs(paletteSwap) do
    directive = string.format("%s;%s=%s", directive, oldColor, newColor)
  end

  animator.setPartTag("base", "paletteSwap", directive)
end