require "/scripts/util.lua"
require "/scripts/vec2.lua"
require "/scripts/rect.lua"
require "/objects/wired/v-monsterwavespawner/v-monsterwavespawner.lua"

local lightBlinkDuration
local openAnimationDuration
local capsuleCloseDelay

local spawnerProjectileType
local spawnerProjectilePosition

local interiorRegionDebug
local exteriorRegionsDebug

local remainingMonsters

local dt
local lightTimer

local oldInit = init or function() end

function init()
  oldInit()

  lightBlinkDuration = config.getParameter("lightBlinkDuration", 0.25)  -- How long it takes for a light to blink once
  openAnimationDuration = config.getParameter("openAnimationDuration", 0.1)
  capsuleCloseDelay = config.getParameter("capsuleCloseDelay", 0.25)

  spawnerProjectileType = config.getParameter("spawnerProjectileType", "v-cityspawnerorb")

  local spawnerProjectileOffset = config.getParameter("spawnerProjectileOffset", {0, 0})
  spawnerProjectilePosition = vec2.add(object.position(), spawnerProjectileOffset)
end

--[[
  OVERRIDE. See v-monsterwavespawner.lua documentation for more details.
]]
function onLoad()
  animator.setGlobalTag("numLights", #storage.waves)  -- #storage.waves is implicitly converted to a string
  animator.setGlobalTag("numActiveLights", "0")
end

--[[
  OVERRIDE. See v-monsterwavespawner.lua documentation for more details.
]]
function onWavesStart()
  dt = script.updateDt()
  lightTimer = lightBlinkDuration
end

--[[
  OVERRIDE. See v-monsterwavespawner.lua documentation for more details.
]]
function onWaveTick(waveNum)
  lightTimer = updateLights(waveNum, lightTimer, dt)
end

--[[
  OVERRIDE. See v-monsterwavespawner.lua documentation for more details.
]]
function onWaveEnd(waveNum)
  animator.setGlobalTag("numActiveLights", waveNum)
end

--[[
  OVERRIDE. See v-monsterwavespawner.lua documentation for more details.
]]
function onDeactivation()
  animator.setGlobalTag("numLights", #storage.waves)  -- #storage.waves is implicitly converted to a string
  animator.setGlobalTag("numActiveLights", #storage.waves)  -- #storage.waves is implicitly converted to a string
end

--[[
  Spawns the monsters in the current wave. Waits until all projectiles spawned die, and the resulting monster IDs are
  populated in the list remainingMonsters (this system must be set up manually).

  wave: A table with the following schema:
    {
      {
        String type: the monster type to spawn
        Vec2F position: the position to spawn the monster at
        Json parameters: the parameters to override
      }
    }
  returns: a list of the IDs of the monsters spawned
]]
function spawnWave(wave)
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
  for _, monster in ipairs(wave.spawners) do
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

function updateLights(waveNum, timer, dt)
  timer = timer - dt
      
  if timer <= 0 then
    timer = lightBlinkDuration
  end
  
  animator.setGlobalTag("numActiveLights", timer <= lightBlinkDuration / 2 and waveNum - 1 or waveNum)
  
  return timer
end