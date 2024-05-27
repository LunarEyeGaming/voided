require "/scripts/util.lua"
require "/scripts/rect.lua"
require "/scripts/voidedutil.lua"

local firstWaveDelay
local nextWaveDelay
local interiorRegion
local exteriorRegions

local waveEntityType
local waveTriggerEntityType

local interiorRegionDebug
local exteriorRegionsDebug

local remainingMonsters

local state

function init()
  firstWaveDelay = config.getParameter("firstWaveDelay", 1.0)
  nextWaveDelay = config.getParameter("nextWaveDelay", 1.0)
  interiorRegion = getRegionPoints(config.getParameter("interiorRegion"))
  waveEntityType = config.getParameter("waveEntityType", "v-wavemonsterspawnpoint")
  waveTriggerEntityType = config.getParameter("waveTriggerEntityType", "v-wavetrigger")

  exteriorRegions = {}
  for _, region in ipairs(config.getParameter("exteriorRegions")) do
    table.insert(exteriorRegions, getRegionPoints(region))
  end
  
  state = FSM:new()
  
  if storage.active == nil then
    storage.active = true
  end
  
  loaded = false  -- Debug variable
  
  reset()
  
  self.debug = true
  interiorRegionDebug = rect.translate(config.getParameter("interiorRegion"), object.position())
  exteriorRegionsDebug = {}
  for _, region in ipairs(config.getParameter("exteriorRegions")) do
    table.insert(exteriorRegionsDebug, rect.translate(region, object.position()))
  end
end

function update(dt)
  util.debugText("loaded: %s", loaded, object.position(), "green")
  
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
  
  onLoad()

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
  
  loaded = true
  
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
  
  onWavesStart()

  for waveNum, wave in ipairs(storage.waves) do
    local remainingMonsters = spawnWave(wave)

    while #remainingMonsters > 0 do
      remainingMonsters = util.filter(remainingMonsters, function(id) return world.entityExists(id) end)
      
      onWaveTick(waveNum)
      
      -- If no friendlies are present in the arena...
      if not friendlyInsideRegion(interiorRegion) then
        -- Despawn all the remaining monsters
        for _, monsterId in ipairs(remainingMonsters) do
          world.sendEntityMessage(monsterId, "despawn")
        end

        -- Tell all trigger targets to reset.
        for _, trigger in ipairs(wave.triggers) do
          -- Query the targets
          local points = getRegionPoints(trigger.queryArea)
          local targets = world.entityQuery(points[1], points[2], trigger.queryOptions)

          -- Send the messages
          for _, target in ipairs(targets) do
            voidedUtil.sendEntityMessage(target, "v-monsterwavespawner-reset")
          end
        end
        
        -- Reset (sets the state to states.postInit())
        reset()
      end
      
      -- Before the loop ends, check if remainingMonsters is empty. If so, then query all monsters with the "enemy"
      -- damage team and make them the remainingMonsters. This check is used to catch monsters that spawned as a result
      -- of other monsters dying.
      if #remainingMonsters == 0 then
        remainingMonsters = world.entityQuery(interiorRegion[1], interiorRegion[2], {includedTypes = {"monster"}})
        
        remainingMonsters = util.filter(remainingMonsters, function(id)
          return world.entityDamageTeam(id).type == "enemy"
        end)
      end
      
      coroutine.yield()
    end
    
    onWaveEnd(waveNum)
    
    util.wait(nextWaveDelay)
  end
  
  deactivate()
  
  state:set(states.inactive)
end

--[[
  Marks this spawner as complete and then does nothing forever.
]]
function states.inactive()
  onDeactivation()

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

  -- Helper function that defines the wave.
  local defineWave = function(waveNum)
    -- Define the wave if it's not defined.
    if not waves[waveNum] then
      waves[waveNum] = {
        spawners = {},
        triggers = {}
      }
    end
  end
  
  -- Function that extracts the wave spawner information
  local successHandlerSpawnpoints = function(promise)
    local spawnpointInfo = promise:result()
      
    defineWave(spawnpointInfo.waveNumber)
    
    -- Insert spawn info
    table.insert(waves[spawnpointInfo.waveNumber].spawners, {
      type = spawnpointInfo.type,
      position = spawnpointInfo.position,
      parameters = spawnpointInfo.parameters
    })
  end
  
  -- Function that extracts the wave trigger information
  local successHandlerTriggers = function(promise, id)
    local triggerInfo = promise:result()
      
    defineWave(triggerInfo.waveNumber)
    
    local triggerPos = world.entityPosition(id)
    local triggerDistance = world.distance(triggerPos, object.position())
    
    -- Insert spawn info
    table.insert(waves[triggerInfo.waveNumber].triggers, {
      messageType = triggerInfo.messageType,
      messageArgs = triggerInfo.messageArgs,
      queryArea = rect.translate(triggerInfo.queryArea, triggerDistance),
      queryOptions = triggerInfo.queryOptions
    })
  end

  local stagehands = world.entityQuery(interiorRegion[1], interiorRegion[2], {includedTypes = {"stagehand"}})
  
  local spawnpoints = util.filter(stagehands, function(id) return world.stagehandType(id) == waveEntityType end)
  local triggers = util.filter(stagehands, function(id) return world.stagehandType(id) == waveTriggerEntityType end)
  
  -- Send out those messages!
  voidedUtil.sendEntityMessageToTargets(successHandlerSpawnpoints, _errorHandler, spawnpoints, "v-getSpawnpointInfo")
  voidedUtil.sendEntityMessageToTargets(successHandlerTriggers, _errorHandler, triggers, "v-getTriggerInfo")
  
  -- Kill spawner stagehands
  for _, spawnpoint in ipairs(spawnpoints) do
    world.sendEntityMessage(spawnpoint, "v-die")
  end
  
  -- Kill trigger stagehands
  for _, trigger in ipairs(triggers) do
    world.sendEntityMessage(trigger, "v-die")
  end
  
  return waves
end

--[[
  Spawns the monsters in the current wave. Returns a list of the monsters spawned.
  wave: A table with the following schema:
    {
      spawners: {
        String type: the monster type to spawn
        Vec2F position: the position to spawn the monster at
        Json parameters: the parameters to override
      },
      triggers: {
        Rect queryArea: the area to query for targets
        Json queryOptions: the options to use when querying the targets
        String messageType: message type to send
        LuaValue List messageArgs: the arguments to give
      }
    }
  returns: a list of the IDs of the monsters spawned
]]
function spawnWave(wave)
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

  -- Spawn the monsters
  -- For each monster spawner in the wave...
  for _, monster in ipairs(wave.spawners) do
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
  
  -- For each trigger in the wave...
  for _, trigger in ipairs(wave.triggers) do
    -- Query the targets
    local points = getRegionPoints(trigger.queryArea)
    local targets = world.entityQuery(points[1], points[2], trigger.queryOptions)

    -- Make the trigger send the messages (no error handler this time).
    voidedUtil.sendEntityMessageToTargets(triggerSuccessHandler, _errorHandler, targets, trigger.messageType, 
        table.unpack(trigger.messageArgs))
  end
  
  return monsterIds
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
    state:set(states.noop)
  end
end

-- HELPER FUNCTIONS
--[[
  Helper function. Logs an error from a promise.
]]
function _errorHandler(promise)
  sb.logError("Promise failed: %s", promise:error())
end

-- HOOKS (may use stubs by default)
--[[
  A function called once the object finishes loading the waves.
]]
function onLoad()

end

--[[
  A function called right before the waves are iterated through
]]
function onWavesStart()

end

--[[
  A function called for each tick spent while a wave is in progress.
  
  param waveNum: the current wave number
]]
function onWaveTick(waveNum)

end

--[[
  A function called when a wave ends.
]]
function onWaveEnd()

end

--[[
  A function called when the object enters the "inactive" state.
]]
function onDeactivation()

end