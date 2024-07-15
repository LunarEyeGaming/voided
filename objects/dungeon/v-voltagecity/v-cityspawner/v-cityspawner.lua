require "/scripts/util.lua"
require "/scripts/vec2.lua"
require "/scripts/rect.lua"
require "/objects/wired/v-monsterwavespawner/v-monsterwavespawner.lua"

local lightBlinkDuration
local openAnimationDuration
local capsuleCloseDelay

local spawnerProjectileType
local gracePeriod
local gracePeriodStartBlinkTime

local spawnerProjectilePosition

local remainingMonsters

local lightTimer
local gracePeriodTimer
local gracePeriodBlinkTime
local gracePeriodNumLights

local oldInit = init or function() end

function init()
  oldInit()

  lightBlinkDuration = config.getParameter("lightBlinkDuration", 0.25)  -- How long it takes for a light to blink once
  openAnimationDuration = config.getParameter("openAnimationDuration", 0.1)
  capsuleCloseDelay = config.getParameter("capsuleCloseDelay", 0.25)

  spawnerProjectileType = config.getParameter("spawnerProjectileType", "v-cityspawnerorb")
  gracePeriod = config.getParameter("gracePeriod")
  gracePeriodStartBlinkTime = config.getParameter("gracePeriodStartBlinkTime", 1.5)

  local spawnerProjectileOffset = config.getParameter("spawnerProjectileOffset", {0, 0})
  spawnerProjectilePosition = vec2.add(object.position(), spawnerProjectileOffset)
end

-- HOOK OVERRIDES. See v-monsterwavespawner.lua documentation for more details.
function onLoad()
  animator.setGlobalTag("numLights", tostring(#storage.waves))
  animator.setGlobalTag("numActiveLights", "0")
end

function onGracePeriodStart()
  gracePeriodTimer = gracePeriod
  gracePeriodBlinkTime = gracePeriodStartBlinkTime
  lightTimer = gracePeriodBlinkTime
end

function onGracePeriodTick(dt)
  gracePeriodTimer = gracePeriodTimer - dt
  lightTimer = lightTimer - dt

  -- Calculate a number interpolated between 0 and #storage.waves using gracePeriodTimer / gracePeriod as the ratio
  local numLightsFloat = gracePeriodTimer / gracePeriod * #storage.waves
  -- Calculate the number of lights when the currently blinking light is OFF
  gracePeriodNumLights = math.floor(numLightsFloat)

  -- Calculate the blink duration for the current light. numLightsFloat - gracePeriodNumLights just happens to return a
  -- value between 0 and 1, so it is a suitable ratio.
  gracePeriodBlinkTime = (numLightsFloat - gracePeriodNumLights) * gracePeriodStartBlinkTime

  if lightTimer <= 0 then
    lightTimer = gracePeriodBlinkTime  -- Reset blink timer
  end

  -- Blinking light is on when lightTimer is less than halfway down. Off otherwise
  local numLights = lightTimer <= gracePeriodBlinkTime / 2 and gracePeriodNumLights or gracePeriodNumLights + 1
  animator.setGlobalTag("numActiveLights", tostring(numLights))
end

function onWavesStart()
  animator.setGlobalTag("numActiveLights", "0")  -- In case a grace period was skipped before this function was called
  lightTimer = lightBlinkDuration
end

function onWaveTick(waveNum, dt)
  lightTimer = lightTimer - dt

  if lightTimer <= 0 then
    lightTimer = lightBlinkDuration
  end

  animator.setGlobalTag("numActiveLights", lightTimer <= lightBlinkDuration / 2 and waveNum - 1 or waveNum)
end

function onWaveEnd(waveNum)
  animator.setGlobalTag("numActiveLights", waveNum)
end

function onDeactivation()
  animator.setGlobalTag("numLights", tostring(#storage.waves))
  animator.setGlobalTag("numActiveLights", tostring(#storage.waves))
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
  -- If the list of spawners is not empty...
    if #waveSpawners > 0 then
    local projectileIds = {}

    local monsterIds = {}  -- Gets populated by the message handler

    animator.setAnimationState("capsule", "opening")
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

    util.wait(capsuleCloseDelay)

    animator.setAnimationState("capsule", "closing")
    animator.playSound("close")

    -- While at least one of the spawned projectiles is still alive...
    while #projectileIds > 0 do
      -- Filter out projectiles that died
      projectileIds = util.filter(projectileIds, function(id) return world.entityExists(id) end)

      coroutine.yield()
    end

    return monsterIds
  end
end