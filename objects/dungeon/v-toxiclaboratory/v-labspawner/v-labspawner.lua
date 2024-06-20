require "/scripts/util.lua"
require "/scripts/vec2.lua"
require "/scripts/rect.lua"
require "/objects/wired/v-monsterwavespawner/v-monsterwavespawner.lua"

local openAnimationDuration
local openingCloseDelay

local spawnerProjectileType

local spawnerProjectilePosition

local remainingMonsters

local oldInit = init or function() end

function init()
  oldInit()

  openAnimationDuration = config.getParameter("openAnimationDuration", 0.2)
  openingCloseDelay = config.getParameter("openingCloseDelay", 0.25)

  spawnerProjectileType = config.getParameter("spawnerProjectileType", "v-cityspawnerorb")

  local spawnerProjectileOffset = config.getParameter("spawnerProjectileOffset", {0, 0})
  spawnerProjectilePosition = vec2.add(object.position(), spawnerProjectileOffset)
end

-- HOOK OVERRIDES. See v-monsterwavespawner.lua documentation for more details.
function onLoad()
  animator.setGlobalTag("numWaves", #storage.waves)  -- #storage.waves is implicitly converted to a string
  animator.setGlobalTag("numCompletedWaves", "0")
  animator.setAnimationState("waveStatus", "inactive")
end

function onGracePeriodStart()
  -- TODO
end

function onGracePeriodTick(dt)
  -- TODO
end

function onWavesStart()
end

function onWaveEnd(waveNum)
  animator.setGlobalTag("numCompletedWaves", waveNum)
  animator.setAnimationState("waveStatus", "inactive")
end

function onDeactivation()
  animator.setGlobalTag("numWaves", #storage.waves)  -- #storage.waves is implicitly converted to a string
  animator.setGlobalTag("numCompletedWaves", #storage.waves)  -- #storage.waves is implicitly converted to a string
end

--[[
  Spawns the monsters in the current wave. Waits until all projectiles spawned die, and the resulting monster IDs are
  populated in the list remainingMonsters.

  waveSpawners: A table with the following schema:
    {
      {
        String type: the monster type to spawn
        Vec2F position: the position to spawn the monster at
        Json parameters: the parameters to override
        boolean silent: whether or not the monster should be silently spawned.
      }
    }
  returns: a list of the IDs of the monsters spawned
]]
function spawnWave(waveSpawners)
  animator.setAnimationState("waveStatus", "transition")

  local projectileIds = {}
  
  local monsterIds = {}  -- Gets populated by the message handler (or by the initial spawnpoint run-through when silent)

  animator.setAnimationState("opening", "opening")
  animator.playSound("open")
  
  util.wait(openAnimationDuration)
  
  -- NOTE: Very slim chance that this will result in a memory leak.
  message.setHandler("v-monsterSpawned", function(_, _, monsterId)
    table.insert(monsterIds, monsterId)
  end)
  
  -- For each monster in the current wave...
  for _, monster in ipairs(waveSpawners) do
    -- If the spawner is not silent...
    if not monster.silent then
      animator.playSound("spawn")

      -- Spawn a projectile that will spawn the monster
      local projectileId = world.spawnProjectile(spawnerProjectileType, spawnerProjectilePosition, entity.id(), {1, 0},
          false, {targetPosition = monster.position, monsterType = monster.type, monsterParameters = monster.parameters})

      table.insert(projectileIds, projectileId)
    else
      -- Spawn the monster directly
      local monsterId = world.spawnMonster(monster.type, monster.position, monster.parameters)
      
      -- If the monster was successfully spawned...
      if monsterId then
        -- Track it.
        table.insert(monsterIds, monsterId)
      else
        sb.logWarn("Monster of type %s at position %s with parameters %s failed to spawn", monster.type,
            monster.position, monster.parameters)
      end
    end
    
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
  
  return monsterIds
end