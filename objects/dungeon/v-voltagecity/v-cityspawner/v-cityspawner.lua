require "/scripts/util.lua"
require "/scripts/vec2.lua"
require "/scripts/rect.lua"

local firstWaveDelay
local nextWaveDelay
local interiorRegion
local waveEntityType

local lightBlinkDuration
local openAnimationDuration
local capsuleCloseDelay

local spawnerProjectileType
local spawnerProjectilePosition

local exteriorRegions

local interiorRegionDebug
local exteriorRegionsDebug

local remainingMonsters

local state

function init()
  firstWaveDelay = config.getParameter("firstWaveDelay", 1.0)
  nextWaveDelay = config.getParameter("nextWaveDelay", 1.0)
  interiorRegion = getRegionPoints(config.getParameter("interiorRegion"))
  waveEntityType = config.getParameter("waveEntityType", "v-wavemonsterspawnpoint")

  lightBlinkDuration = config.getParameter("lightBlinkDuration", 0.25)  -- How long it takes for a light to blink once
  openAnimationDuration = config.getParameter("openAnimationDuration", 0.1)
  capsuleCloseDelay = config.getParameter("capsuleCloseDelay", 0.25)

  spawnerProjectileType = config.getParameter("spawnerProjectileType", "v-cityspawnerorb")

  local spawnerProjectileOffset = config.getParameter("spawnerProjectileOffset", {0, 0})
  spawnerProjectilePosition = vec2.add(object.position(), spawnerProjectileOffset)

  -- Convert from a Rect to a list of Vec2's
  exteriorRegions = {}
  for _, region in ipairs(config.getParameter("exteriorRegions")) do
    table.insert(exteriorRegions, getRegionPoints(region))
  end
  
  state = FSM:new()
  
  if storage.active == nil then
    storage.active = true
  end
  
  active = false  -- Debug variable
  
  reset()
  
  self.debug = true
  interiorRegionDebug = rect.translate(config.getParameter("interiorRegion"), object.position())
  exteriorRegionsDebug = {}
  for _, region in ipairs(config.getParameter("exteriorRegions")) do
    table.insert(exteriorRegionsDebug, rect.translate(region, object.position()))
  end

  remainingMonsters = {}  -- Used in the spawnWave() function.

  message.setHandler("v-monsterSpawned", function(_, _, monsterId)
    table.insert(remainingMonsters, monsterId)
  end)
end

function update(dt)
  world.debugText("active: %s", active, object.position(), "green")
  
  util.debugRect(interiorRegionDebug, "green")

  for _, region in ipairs(exteriorRegionsDebug) do
    util.debugRect(region, "red")
  end

  state:update()
end

states = {}

--[[
  Does initialization things that cannot be done in the init() function and have to be done across multiple ticks.
]]
function states.postInit()
  if not storage.waves then
    local interiorRegionRect = rect.fromVec2(interiorRegion[1], interiorRegion[2])

    -- Wait for the region to fully load before querying anything.
    while not world.regionActive(interiorRegionRect) do
      coroutine.yield()
    end

    storage.waves = getWaves()
  end

  animator.setGlobalTag("numLights", #storage.waves)  -- #storage.waves is implicitly converted to a string
  animator.setGlobalTag("numActiveLights", "0")

  state:set(states.wait)
end

--[[
  Waits for any creature with a friendly damage team to be inside the arena and for no creatures with a friendly damage
  team to be outside of it.
]]
function states.wait()
  -- While no "friendly" creatures are in the arena or at least one "friendly" creature is outside the arena, do 
  -- nothing.
  while not friendlyInsideRegion(interiorRegion) or friendlyInsideRegions(exteriorRegions) do
    coroutine.yield()
  end
  
  active = true
  
  -- state:set(states.noop)
  
  activate()
  
  state:set(states.waves)
end

--[[
  Spawns waves of enemies one by one. Waits until the current wave is cleared to spawn the next one, and repeats until
  all waves have been cleared. Once this is the case, the object permanently deactivates and will never spawn monsters
  again. However, if no friendlies are present in the arena anymore (i.e. died), then the object will despawn all
  monsters and reset itself. 
]]
function states.waves()
  util.wait(firstWaveDelay)
  
  local dt = script.updateDt()
  local lightTimer = lightBlinkDuration

  for waveNum, wave in ipairs(storage.waves) do
    spawnWave(wave)

    while #remainingMonsters > 0 do
      remainingMonsters = util.filter(remainingMonsters, function(id) return world.entityExists(id) end)
      
      lightTimer = updateLights(waveNum, lightTimer, dt)
      
      -- If no friendlies are present in the arena...
      if not friendlyInsideRegion(interiorRegion) then
        -- Despawn all the remaining monsters
        for _, monsterId in ipairs(remainingMonsters) do
          world.sendEntityMessage(monsterId, "despawn")
        end
        
        -- Reset (sets the state to states.postInit())
        reset()
      end
      
      coroutine.yield()
    end
  
    animator.setGlobalTag("numActiveLights", waveNum)
    
    util.wait(nextWaveDelay)
  end
  
  deactivate()
  
  state:set(states.noop)
end

--[[
  Marks this spawner as complete and then does nothing forever.
]]
function states.inactive()
  animator.setGlobalTag("numLights", #storage.waves)  -- #storage.waves is implicitly converted to a string
  animator.setGlobalTag("numActiveLights", #storage.waves)  -- #storage.waves is implicitly converted to a string

  while true do
    coroutine.yield()
  end
end

--[[
  Closes the doors
]]
function activate()
  object.setAllOutputNodes(false)
end

--[[
  Opens the doors, makes all lights active, and permanently deactivates itself
]]
function deactivate()
  object.setAllOutputNodes(true)
  
  animator.setGlobalTag("numActiveLights", #storage.waves)
  
  storage.active = false
end

--[[
  Returns a list of waves extracted from stagehands that designate monster types and where they spawn as well as their
  parameters.
]]
function getWaves()
  local waves = {}

  local stagehands = world.entityQuery(interiorRegion[1], interiorRegion[2], {includedTypes = {"stagehand"}})
  
  local spawnpoints = util.filter(stagehands, function(id) return world.stagehandType(id) == waveEntityType end)
  
  -- sb.logInfo("stagehands: %s", stagehands)
  -- sb.logInfo("spawnpoints: %s", spawnpoints)
  
  local promises = {}
  
  -- Probably unnecessary, but I have the gut feeling that the return times of each promise can vary.
  for _, spawnpoint in ipairs(spawnpoints) do
    table.insert(promises, world.sendEntityMessage(spawnpoint, "v-getSpawnpointInfo"))
  end
  
  for _, promise in ipairs(promises) do
    -- Wait for the promise to finish.
    while not promise:finished() do
      coroutine.yield()
    end

    if promise:succeeded() then
      local spawnpointInfo = promise:result()
      
      -- Define the wave if it's not defined
      if not waves[spawnpointInfo.waveNumber] then
        waves[spawnpointInfo.waveNumber] = {}
      end
      
      -- Insert spawn info
      table.insert(waves[spawnpointInfo.waveNumber], {
        type = spawnpointInfo.type,
        position = spawnpointInfo.position,
        parameters = spawnpointInfo.parameters
      })
    else
      sb.logError("Promise failed: %s", promise:error())
    end
  end
  
  for _, spawnpoint in ipairs(spawnpoints) do
    world.sendEntityMessage(spawnpoint, "v-die")
  end
  
  return waves
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
]]
function spawnWave(wave)
  local projectileIds = {}
  
  remainingMonsters = {}  -- Gets populated by the message handler

  animator.setAnimationState("capsule", "opening")
  animator.playSound("open")
  
  util.wait(openAnimationDuration)
  
  -- For each monster in the current wave...
  for _, monster in ipairs(wave) do
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
end

--[[
  Returns true if at least one creature with a friendly damage team is inside the given region and false otherwise.
  
  region: A pair of Vec2F's
]]
function friendlyInsideRegion(region)
  local queried = world.entityQuery(region[1], region[2], {includedTypes = {"creature"}})
  
  for _, entityId in ipairs(queried) do
    local entityDamageTeam = world.entityDamageTeam(entityId)
    if entityDamageTeam.type == "friendly" then
      return true
    end
  end
  
  return false
end

--[[
  Returns true if at least one creature with a friendly damage team is inside at least one of the given regions and 
  false otherwise.
  
  regions: A list of Vec2F pairs
]]
function friendlyInsideRegions(regions)
  for _, region in ipairs(regions) do
    if friendlyInsideRegion(region) then
      return true
    end
  end
  
  return false
end

--[[
  Converts a relative rectangle into a table of the bottom-left and top-right points (absolute) and returns the result.
]]
function getRegionPoints(rectangle)
  local absoluteRectangle = rect.translate(rectangle, object.position())
  
  return {rect.ll(absoluteRectangle), rect.ur(absoluteRectangle)}
end

--[[
  If the room was not cleared, opens one door, leaves the other closed, and waits for friendlies to enter. Otherwise,
  opens all doors and never activates again.
]]
function reset()
  object.setOutputNodeLevel(0, true)
  
  if storage.active then
    object.setOutputNodeLevel(1, false)
    state:set(states.postInit)
  else
    object.setOutputNodeLevel(1, true)
    state:set(states.inactive)
  end
end

function updateLights(waveNum, timer, dt)
  timer = timer - dt
      
  if timer <= 0 then
    timer = lightBlinkDuration
  end
  
  animator.setGlobalTag("numActiveLights", timer <= lightBlinkDuration / 2 and waveNum - 1 or waveNum)
  
  return timer
end