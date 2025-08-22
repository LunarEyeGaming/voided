require "/scripts/util.lua"
require "/scripts/vec2.lua"
require "/scripts/rect.lua"
require "/objects/wired/v-monsterwavespawner/v-monsterwavespawner.lua"
require "/scripts/v-animator.lua"

local openAnimationDuration
local openingCloseDelay

local spawnerProjectileType

local portalMinSize
local portalSizeStep

local portalAppearTime
local portalDisappearTime
local portalDownsizeSpeed

local portalLightningFadeTime
local portalLightningStartColor
local portalLightningEndColor
local portalLightningStartOutlineColor
local portalLightningEndOutlineColor
local portalLightningConfig

local gracePeriod
local gracePeriodTimer

local spawnerProjectilePosition

local lightningController

local oldInit = init or function() end
local oldUpdate = update or function() end

function init()
  oldInit()

  openAnimationDuration = config.getParameter("openAnimationDuration", 0.2)
  openingCloseDelay = config.getParameter("openingCloseDelay", 0.25)

  spawnerProjectileType = config.getParameter("spawnerProjectileType", "v-cityspawnerorb")

  portalMinSize = config.getParameter("portalMinSize")
  portalSizeStep = config.getParameter("portalSizeStep")

  portalAppearTime = config.getParameter("portalAppearTime")
  portalDisappearTime = config.getParameter("portalDisappearTime")
  portalDownsizeSpeed = config.getParameter("portalDownsizeSpeed")

  portalLightningFadeTime = config.getParameter("portalLightningFadeTime")
  portalLightningStartColor = config.getParameter("portalLightningStartColor")
  portalLightningEndColor = config.getParameter("portalLightningEndColor")
  portalLightningStartOutlineColor = config.getParameter("portalLightningStartOutlineColor")
  portalLightningEndOutlineColor = config.getParameter("portalLightningEndOutlineColor")
  portalLightningConfig = config.getParameter("portalLightningConfig")

  gracePeriod = config.getParameter("gracePeriod")

  local spawnerProjectileOffset = config.getParameter("spawnerProjectileOffset", {0, 0})
  spawnerProjectilePosition = vec2.add(object.position(), spawnerProjectileOffset)

  lightningController = vAnimator.LightningController:new(
    portalLightningConfig,
    portalLightningStartColor,
    portalLightningEndColor,
    portalLightningFadeTime,
    false,
    portalLightningStartOutlineColor,
    portalLightningEndOutlineColor
  )
end

function update(dt)
  oldUpdate(dt)

  lightningController:update(dt)
end

-- HOOK OVERRIDES. See v-monsterwavespawner.lua documentation for more details.
function onLoad()
  -- animator.setGlobalTag("numWaves", tostring(#storage.waves))
  -- animator.setGlobalTag("numCompletedWaves", "0")
  -- animator.setAnimationState("waveStatus", "inactive")
end

function onGracePeriodStart()
  -- gracePeriodTimer = 0
end

function onGracePeriodTick(dt)
  -- gracePeriodTimer = gracePeriodTimer + dt

  -- -- Spend gracePeriodPaletteSwapTime transitioning to the new colors
  -- if gracePeriodTimer < gracePeriodPaletteSwapTime then
  --   local newPaletteSwap = {}

  --   for oldColor, newColorT in pairs(gracePeriodStartPaletteSwap) do
  --     -- Calculate progress ratio
  --     local progress = gracePeriodTimer / gracePeriodPaletteSwapTime

  --     -- Get old color table
  --     local oldColorT = gracePeriodEndPaletteSwap[oldColor]

  --     -- Lerp to new color
  --     newPaletteSwap[oldColor] = vAnimator.colorToString(vAnimator.lerpColorRGB(progress, oldColorT, newColorT))
  --   end

  --   applyPaletteSwap(newPaletteSwap)
  -- else  -- Spend remaining time transitioning to the old colors.
  --   local newPaletteSwap = {}

  --   for oldColor, newColorT in pairs(gracePeriodStartPaletteSwap) do
  --     -- Calculate progress ratio. Account for the delay in the calculations.
  --     local progress = (gracePeriodTimer - gracePeriodPaletteSwapTime) / (gracePeriod - gracePeriodPaletteSwapTime)

  --     -- Get old color table
  --     local oldColorT = gracePeriodEndPaletteSwap[oldColor]

  --     -- Lerp back to old color
  --     newPaletteSwap[oldColor] = vAnimator.colorToString(vAnimator.lerpColorRGB(progress, newColorT, oldColorT))
  --   end

  --   applyPaletteSwap(newPaletteSwap)
  -- end
end

function onActivation()
  animator.playSound("shatter")
  animator.burstParticleEmitter("shatter")
  animator.setAnimationState("glass", "broken")

  animator.setAnimationState("portalunstable", "visible")
  animator.setPartTag("portalunstable", "opacity", "00")

  animator.resetTransformationGroup("portalunstable")
  animator.scaleTransformationGroup("portalunstable", {portalMinSize, portalMinSize})

  local portalMaxSize = portalMinSize + portalSizeStep * #storage.waves

  local timer = 0
  local dt = script.updateDt()
  util.wait(portalAppearTime, function()
    local progress = timer / portalAppearTime
    local portalSize = util.lerp(progress, portalMinSize, portalMaxSize)
    animator.resetTransformationGroup("portalunstable")
    animator.scaleTransformationGroup("portalunstable", {portalSize, portalSize})
    animator.setPartTag("portalunstable", "opacity", string.format("%02x", math.floor(255 * progress)))

    timer = timer + dt
  end)

  animator.setPartTag("portalunstable", "opacity", "ff")
end

function onWaveEnd(waveNum)
end

function onDeactivation()
  local timer = 0
  local dt = script.updateDt()
  util.wait(portalDisappearTime, function()
    local progress = 1 - timer / portalDisappearTime
    animator.setPartTag("portalunstable", "opacity", string.format("%02x", math.floor(255 * progress)))

    timer = timer + dt
  end)

  animator.setAnimationState("portalunstable", "invisible")
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
function spawnWave(waveSpawners, waveNum)
  local monsterIds = {}  -- Gets populated by the message handler

  -- Set when finished spawning to avoid some weird updating jank.
  object.setAnimationParameter("lightningSeed", math.floor(os.clock()))

  -- If the list of spawners is not empty...
  if #waveSpawners > 0 then
    local wavesRemaining = #storage.waves - waveNum + 1
    local targetPortalSize = portalMinSize + portalSizeStep * wavesRemaining

    local baseThread = coroutine.create(function()
      local projectileIds = {}

      animator.playSound("spawn")

      -- local timer = 0
      -- local dt = script.updateDt()
      -- util.wait(portalScaleTime, function()
      --   local progress = timer / portalScaleTime
      --   local portalSize = util.lerp(progress, portalMinSize + portalSizeStep * waveNum, portalMinSize + portalSizeStep * (waveNum - 1))
      --   animator.resetTransformationGroup("portalunstable")
      --   animator.scaleTransformationGroup("portalunstable", {portalSize, portalSize})
      --   timer = timer + dt
      -- end)

      -- NOTE: Very slim chance that this will result in a memory leak.
      message.setHandler("v-monsterSpawned", function(_, _, monsterId)
        table.insert(monsterIds, monsterId)
      end)

      -- For each monster in the current wave...
      local numWaveSpawners = #waveSpawners
      for i, monster in ipairs(waveSpawners) do
        lightningController:add(spawnerProjectilePosition, monster.position)

        -- Spawn a projectile that will spawn the monster
        local projectileId = world.spawnProjectile(spawnerProjectileType, monster.position, entity.id(), {1, 0},
            false, {monsterType = monster.type, monsterParameters = monster.parameters})

        table.insert(projectileIds, projectileId)

        local progress = i / numWaveSpawners
        targetPortalSize = util.lerp(progress, portalMinSize + portalSizeStep * wavesRemaining, portalMinSize + portalSizeStep * (wavesRemaining - 1))
      end

      -- While at least one of the spawned projectiles is still alive...
      while #projectileIds > 0 do
        -- Filter out projectiles that died
        projectileIds = util.filter(projectileIds, function(id) return world.entityExists(id) end)

        coroutine.yield()
      end
    end)
    local kinematicsThread = coroutine.create(function()
      local dt = script.updateDt()
      local portalSize = portalMinSize + portalSizeStep * wavesRemaining

      while true do
        animator.resetTransformationGroup("portalunstable")
        animator.scaleTransformationGroup("portalunstable", {portalSize, portalSize})

        -- Approach portal size.
        if portalSize > targetPortalSize then
          portalSize = portalSize - portalDownsizeSpeed * dt
        else
          portalSize = portalSize + portalDownsizeSpeed * dt
        end

        coroutine.yield()
      end
    end)

    while util.parallel(baseThread, kinematicsThread) do
      coroutine.yield()
    end
  end

  return monsterIds
end