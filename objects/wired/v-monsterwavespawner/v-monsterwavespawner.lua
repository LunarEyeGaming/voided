require "/scripts/util.lua"
require "/scripts/rect.lua"

local firstWaveDelay
local nextWaveDelay
local interiorRegion
local exteriorRegion

local state

function init()
  firstWaveDelay = config.getParameter("firstWaveDelay", 1.0)
  nextWaveDelay = config.getParameter("nextWaveDelay", 1.0)
  interiorRegion = getRegionPoints(config.getParameter("interiorRegion"))
  waveEntityType = config.getParameter("waveEntityType", "v-wavemonsterspawnpoint")

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

  for _, wave in ipairs(storage.waves) do
    local remainingMonsters = spawnWave(wave)

    while #remainingMonsters > 0 do
      -- TODO: Despawn all monsters and reset once all friendlies are not present
      remainingMonsters = util.filter(remainingMonsters, function(id) return world.entityExists(id) end)
      
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
    
    util.wait(nextWaveDelay)
    -- TODO: Reset once all friendlies are not present
  end
  
  deactivate()
  
  state:set(states.noop)
end

--[[
  Does nothing.
]]
function states.noop()
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
  Opens the doors and permanently deactivates itself
]]
function deactivate()
  object.setAllOutputNodes(true)
  
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
  Spawns the monsters in the current wave. Returns a list of the monsters spawned.
  wave: A table with the following schema:
    {
      {
        {
          String type: the monster type to spawn
          Vec2F position: the position to spawn the monster at
          Json parameters: the parameters to override
        }
      }
    }
  returns: a list of the IDs of the monsters spawned
]]
function spawnWave(wave)
  local monsterIds = {}

  -- For each monster spawner in the wave...
  for _, monster in ipairs(wave) do
    -- Spawn the monster
    local monsterId = world.spawnMonster(monster.type, monster.position, monster.parameters)
    
    -- If the monster was successfully spawned...
    if monsterId then
      -- Track it.
      table.insert(monsterIds, monsterId)
    else
      sb.logWarn("Monster of type %s at position %s with parameters %s failed to spawn", monster.type, monster.position,
          monster.parameters)
    end
  end
  
  return monsterIds
end

-- Returns true if at least one creature with a friendly damage team is inside the given region and false otherwise.
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

-- Returns true if at least one creature with a friendly damage team is inside at least one of the given regions and
-- false otherwise.
function friendlyInsideRegions(regions)
  for _, region in ipairs(regions) do
    if friendlyInsideRegion(region) then
      return true
    end
  end
  
  return false
end

-- Converts a relative rectangle into a table of the bottom-left and top-right points (absolute) and returns the result.
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
    state:set(states.noop)
  end
end