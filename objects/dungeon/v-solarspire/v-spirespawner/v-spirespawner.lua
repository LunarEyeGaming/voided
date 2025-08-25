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

local preSpawnSparkTime

local portalLightningFadeTime
local portalLightningStartColor
local portalLightningEndColor
local portalLightningStartOutlineColor
local portalLightningEndOutlineColor
local portalLightningConfig

local gracePeriod
local gracePeriodTimer
local gracePeriodSparkChanceMultiplier

local minTriggerDelay

local portalLightningStartPosition

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

  preSpawnSparkTime = config.getParameter("preSpawnSparkTime")

  portalLightningFadeTime = config.getParameter("portalLightningFadeTime")
  portalLightningStartColor = config.getParameter("portalLightningStartColor")
  portalLightningEndColor = config.getParameter("portalLightningEndColor")
  portalLightningStartOutlineColor = config.getParameter("portalLightningStartOutlineColor")
  portalLightningEndOutlineColor = config.getParameter("portalLightningEndOutlineColor")
  portalLightningConfig = config.getParameter("portalLightningConfig")

  gracePeriod = config.getParameter("gracePeriod")
  gracePeriodSparkChanceMultiplier = config.getParameter("gracePeriodSparkChanceMultiplier")

  minTriggerDelay = config.getParameter("minTriggerDelay")

  local portalLightningStartOffset = config.getParameter("portalLightningStartOffset", {0, 0})
  portalLightningStartPosition = vec2.add(object.position(), portalLightningStartOffset)

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
  animator.setAnimationState("portal", "idleactive")
  animator.setParticleEmitterActive("portalsparks", false)
  animator.setAnimationState("portalunstable", "invisible")
  animator.setPartTag("portalunstable", "opacity", "00")
  animator.stopAllSounds("sparks")
end

function onGracePeriodStart()
  gracePeriodTimer = 0
end

function onGracePeriodTick(dt)
  gracePeriodTimer = gracePeriodTimer + dt

  local ratio = gracePeriodTimer / gracePeriod

  if math.random() < ratio * gracePeriodSparkChanceMultiplier then
    animator.burstParticleEmitter("portalsparks")
    animator.playSound("sparkBurst")
  end
end

function onActivation()
  if not storage.hasGracePeriod then
    animator.playSound("shatter")
    animator.burstParticleEmitter("shatter")
    animator.setAnimationState("glass", "broken")
  end

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

  animator.setAnimationState("portal", "idle")
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
    animator.playSound("sparks", -1)
    animator.setParticleEmitterActive("portalsparks", true)
    util.wait(preSpawnSparkTime)
    animator.setParticleEmitterActive("portalsparks", false)
    animator.stopAllSounds("sparks")

    local wavesRemaining = #storage.waves - waveNum + 1
    local initialPortalSize = portalMinSize + portalSizeStep * wavesRemaining
    local targetPortalSizeRef = {v = initialPortalSize}

    local baseThread = coroutine.create(function()
      local projectileIds = {}

      animator.playSound("lightningStrike")

      -- NOTE: Very slim chance that this will result in a memory leak.
      message.setHandler("v-monsterSpawned", function(_, _, monsterId)
        table.insert(monsterIds, monsterId)
      end)

      -- For each monster in the current wave...
      local numWaveSpawners = #waveSpawners
      for i, monster in ipairs(waveSpawners) do
        lightningController:add(portalLightningStartPosition, monster.position)

        -- Spawn a projectile that will spawn the monster
        local projectileId = world.spawnProjectile(spawnerProjectileType, monster.position, entity.id(), {1, 0},
            false, {monsterType = monster.type, monsterParameters = monster.parameters})

        table.insert(projectileIds, projectileId)

        local progress = i / numWaveSpawners
        targetPortalSizeRef.v = util.lerp(progress, portalMinSize + portalSizeStep * wavesRemaining, portalMinSize + portalSizeStep * (wavesRemaining - 1))
      end

      -- While at least one of the spawned projectiles is still alive...
      while #projectileIds > 0 do
        -- Filter out projectiles that died
        projectileIds = util.filter(projectileIds, function(id) return world.entityExists(id) end)

        coroutine.yield()
      end
    end)
    local kinematicsThread = coroutine.create(portalKinematicsGen(initialPortalSize, targetPortalSizeRef))

    while util.parallel(baseThread, kinematicsThread) do
      coroutine.yield()
    end
  end

  return monsterIds
end

function activateTriggers(waveTriggers)
  local monsterIds = {}

  -- Function to add the returned monster ID to the list.
  local triggerSuccessHandler = function(promise)
    local returnedMonsterIds = promise:result()

    -- If a list of monster IDs was returned...
    if returnedMonsterIds then
      -- Add each monster ID to the monsterIds table.
      for _, id in ipairs(returnedMonsterIds) do
        table.insert(monsterIds, id)
      end
    end
  end

  if #waveTriggers > 0 then
    animator.playSound("sparks", -1)
    animator.setParticleEmitterActive("portalsparks", true)
    util.wait(preSpawnSparkTime)

    -- For each trigger in the wave...
    for _, trigger in ipairs(waveTriggers) do
      if trigger.messageType and trigger.messageType ~= "" then
        util.wait(math.max(0.05, trigger.delay))  -- This makes it wait at least a certain amount of time

        animator.playSound("lightningStrike")

        -- Query the targets
        local points = vEntity.getRegionPoints(trigger.queryArea)
        local targets = world.entityQuery(points[1], points[2], trigger.queryOptions)

        local endPosition = vec2.add(object.position(), rect.center(trigger.queryArea))
        lightningController:add(portalLightningStartPosition, endPosition)

        -- sb.logInfo("Activating trigger: %s", trigger)

        -- Make the trigger send the messages (no error handler this time).
        vWorldA.sendEntityMessageToTargets(triggerSuccessHandler, function() end, targets, trigger.messageType,
            table.unpack(trigger.messageArgs))
      end
    end

    animator.setParticleEmitterActive("portalsparks", false)
    animator.stopAllSounds("sparks")
  end

  return monsterIds
end

function portalKinematicsGen(initialPortalSize, targetPortalSizeRef)
  return function()
      local dt = script.updateDt()
      local portalSize = initialPortalSize

      while true do
        animator.resetTransformationGroup("portalunstable")
        animator.scaleTransformationGroup("portalunstable", {portalSize, portalSize})

        -- Approach portal size.
        if portalSize > targetPortalSizeRef.v then
          portalSize = portalSize - portalDownsizeSpeed * dt
        else
          portalSize = portalSize + portalDownsizeSpeed * dt
        end

        coroutine.yield()
      end
    end
end