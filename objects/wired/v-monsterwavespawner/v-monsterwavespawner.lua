require "/scripts/util.lua"
require "/scripts/rect.lua"

require "/scripts/v-world.lua"
require "/scripts/v-entity.lua"

local firstWaveDelay
local nextWaveDelay
local interiorRegion
local exteriorRegions
local gracePeriod
local gracePeriodRadioMessages

local interiorRegionDebug
local exteriorRegionsDebug

local skippedGracePeriod

local state

-- HOOKS
function init()
  firstWaveDelay = config.getParameter("firstWaveDelay", 1.0)
  nextWaveDelay = config.getParameter("nextWaveDelay", 1.0)
  interiorRegion = vEntity.getRegionPoints(config.getParameter("interiorRegion"))
  gracePeriod = config.getParameter("gracePeriod")
  gracePeriodRadioMessages = config.getParameter("gracePeriodRadioMessages")

  exteriorRegions = {}
  for _, region in ipairs(config.getParameter("exteriorRegions")) do
    table.insert(exteriorRegions, vEntity.getRegionPoints(region))
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

  skippedGracePeriod = false  -- Whether or not the player has skipped the grace period yet.
end

function update(dt)
  if not loaded then
    util.debugText("loading...", object.position(), "green")
  end

  util.debugRect(interiorRegionDebug, "green")

  for _, region in ipairs(exteriorRegionsDebug) do
    util.debugRect(region, "red")
  end

  state:update()
end

function onInteraction(args)
  skippedGracePeriod = true
end

function onNodeConnectionChange(args)
  storage.hasActiveInput = not object.isInputNodeConnected(0) or object.getInputNodeLevel(0)
end

function onInputNodeChange(args)
  storage.hasActiveInput = not object.isInputNodeConnected(0) or object.getInputNodeLevel(0)
end

-- STATE FUNCTIONS
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

    local waves, activationZones = getWaves()
    storage.waves = waves

    if #activationZones == 0 then
      storage.activationZones = {interiorRegion}
    else
      storage.activationZones = activationZones
    end
  -- If the waves were retrieved before but there are no activation zones, define them.
  elseif not storage.activationZones then
    storage.activationZones = {interiorRegion}
  end

  onLoad()

  loaded = true

  coroutine.yield()

  state:set(states.wait)
end

--[[
  Waits for any creature with a friendly damage team to be inside the arena and for no creatures with a friendly damage
  team to be outside of it.
]]
function states.wait()
  if not storage.wasActivated then
    while not storage.hasActiveInput do
      coroutine.yield()
    end

    storage.wasActivated = true
    onInputActivation()
  end

  -- While no "friendly" creatures are in the arena or at least one "friendly" creature is outside the arena, do
  -- nothing.
  while not friendlyInsideRegions(storage.activationZones) or friendlyInsideRegions(exteriorRegions) do
    coroutine.yield()
  end

  activate()
  onActivation()

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

  -- If a grace period is allowed...
  if storage.hasGracePeriod then
    -- Send a series of radio messages to all players in the arena.
    local queried = world.entityQuery(interiorRegion[1], interiorRegion[2], {includedTypes = {"player"}})

    for _, entityId in ipairs(queried) do
      for _, msg in ipairs(gracePeriodRadioMessages) do
        world.sendEntityMessage(entityId, "queueRadioMessage", msg)
      end
    end

    onGracePeriodStart()

    object.setInteractive(true)

    skippedGracePeriod = false  -- Reset skippedGracePeriod variable

    local timer = 0
    util.wait(gracePeriod, function(dt)
      onGracePeriodTick(dt)

      timer = timer + dt
      util.debugText("grace period: %s", timer, object.position(), "green")

      -- If the grace period was skipped due to a player interaction...
      if skippedGracePeriod then
        return true  -- Force the grace period to end prematurely by returning true
      end
    end)

    object.setInteractive(false)
  end

  onWavesStart()

  local dt = script.updateDt()

  for waveNum, wave in ipairs(storage.waves) do
    local remainingMonsters = spawnWave(wave.spawners, waveNum)
    local temp = spawnWaveSilent(wave.silentSpawners)
    local temp2 = activateTriggers(wave.triggers)

    -- Concatenate temp to remainingMonsters
    for _, monsterId in ipairs(temp) do
      table.insert(remainingMonsters, monsterId)
    end

    -- Concatenate temp2 to remainingMonsters
    for _, monsterId in ipairs(temp2) do
      table.insert(remainingMonsters, monsterId)
    end

    -- Listen for monsters that were spawned.
    message.setHandler("v-monsterwavespawner-monsterspawned", function(_, _, id)
      table.insert(remainingMonsters, id)
    end)

    while #remainingMonsters > 0 do
      remainingMonsters = util.filter(remainingMonsters, function(id) return world.entityExists(id) end)

      if self.debug then
        for _, monsterId in ipairs(remainingMonsters) do
          world.debugPoint(world.entityPosition(monsterId), "magenta")
        end
      end

      onWaveTick(waveNum, dt)

      -- If no friendlies are present in the arena...
      if not friendlyInsideRegion(interiorRegion) then
        -- Despawn all the remaining monsters
        for _, monsterId in ipairs(remainingMonsters) do
          world.sendEntityMessage(monsterId, "despawn")
        end

        resetTriggers(waveNum)

        -- Reset (sets the state to states.postInit())
        reset()

        -- Allow for grace period
        if not storage.hasGracePeriod then
          storage.hasGracePeriod = true
        end
      end

      coroutine.yield()
    end

    onWaveEnd(waveNum)

    util.wait(nextWaveDelay)
  end

  deactivateTriggers()

  deactivate()

  state:set(states.inactive)
end

--[[
  Marks this spawner as complete and then does nothing forever.
]]
function states.inactive()
  coroutine.yield()

  onDeactivation()

  while true do
    coroutine.yield()
  end
end

-- HELPER FUNCTIONS
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

  It also returns a list of the activation zones to check as specified by stagehands of type `v-waveactivationzone`.
]]
function getWaves()
  local waveEntityType = config.getParameter("waveEntityType", "v-wavemonsterspawnpoint")
  local waveTriggerEntityType = config.getParameter("waveTriggerEntityType", "v-wavetrigger")
  local activationZoneEntityType = config.getParameter("activationZoneEntityType", "v-waveactivationzone")

  local waves = {}
  local activationZones = {}

  local killStagehands = function(stagehands)
    for _, id in ipairs(stagehands) do
      world.sendEntityMessage(id, "v-die")
    end
  end

  -- Helper function that defines the wave.
  local defineWave = function(waveNum)
    -- Define the wave if it's not defined.
    if not waves[waveNum] then
      waves[waveNum] = {
        spawners = {},
        silentSpawners = {},
        triggers = {}
      }
    end
  end

  -- Function that extracts the wave spawner information
  local successHandlerSpawnpoints = function(promise)
    local spawnpointInfo = promise:result()

    defineWave(spawnpointInfo.waveNumber)

    -- If the spawnpoint is "silent"...
    if spawnpointInfo.silent then
      -- Insert spawn info into the list of silent spawners
      table.insert(waves[spawnpointInfo.waveNumber].silentSpawners, {
        type = spawnpointInfo.type,
        position = spawnpointInfo.position,
        parameters = spawnpointInfo.parameters
      })
    else
      -- Insert spawn info into the list of normal spawners
      table.insert(waves[spawnpointInfo.waveNumber].spawners, {
        type = spawnpointInfo.type,
        position = spawnpointInfo.position,
        parameters = spawnpointInfo.parameters
      })
    end
  end

  -- Function that extracts the wave trigger information
  local successHandlerTriggers = function(promise, id)
    local triggerInfo = promise:result()

    defineWave(triggerInfo.waveNumber)

    local triggerPos = world.entityPosition(id)
    local triggerDistance = world.distance(triggerPos, object.position())

    -- Insert trigger info
    table.insert(waves[triggerInfo.waveNumber].triggers, {
      messageType = triggerInfo.messageType,
      messageArgs = triggerInfo.messageArgs,
      queryArea = rect.translate(triggerInfo.queryArea, triggerDistance),
      queryOptions = triggerInfo.queryOptions,
      resetOnSubsequentWaves = triggerInfo.resetOnSubsequentWaves,
      deactivateOnCompletion = triggerInfo.deactivateOnCompletion,

      delay = triggerInfo.delay or 0.0,
      priority = triggerInfo.priority or 0
    })
  end

  -- Function that extracts activation zone information
  local successHandlerActivationZones = function(promise, id)
    local zone = promise:result()

    table.insert(activationZones, zone)
  end

  local stagehands = world.entityQuery(interiorRegion[1], interiorRegion[2], {includedTypes = {"stagehand"}})

  local spawnpoints = util.filter(stagehands, function(id) return world.stagehandType(id) == waveEntityType end)
  local triggers = util.filter(stagehands, function(id) return world.stagehandType(id) == waveTriggerEntityType end)
  local activationZoneStagehands = util.filter(stagehands, function(id) return world.stagehandType(id) == activationZoneEntityType end)

  -- Send out those messages!
  vWorldA.sendEntityMessageToTargets(successHandlerSpawnpoints, _errorHandler("Promise failed for v-getSpawnpointInfo"), spawnpoints, "v-getSpawnpointInfo")
  vWorldA.sendEntityMessageToTargets(successHandlerTriggers, _errorHandler("Promise failed for v-getTriggerInfo"), triggers, "v-getTriggerInfo")
  vWorldA.sendEntityMessageToTargets(successHandlerActivationZones, _errorHandler("Promise failed for v-getActivationZone"), activationZoneStagehands, "v-getActivationZone")

  -- Kill stagehands that were used
  killStagehands(spawnpoints)
  killStagehands(triggers)
  killStagehands(activationZoneStagehands)

  -- Sort wave triggers by priority.
  for _, wave in ipairs(waves) do
    table.sort(wave.triggers, function(triggerA, triggerB)
      return triggerA.priority < triggerB.priority
    end)
  end

  return waves, activationZones
end

--[[
  Spawns the monsters in the current wave. Returns a list of the monsters spawned.
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
  local monsterIds = {}

  -- Spawn the monsters
  -- For each monster spawner in the wave...
  for _, monster in ipairs(waveSpawners) do
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

--[[
  Spawns the monsters in the current wave using silent spawners. Returns a list of the monsters spawned. Normally, this
  is identical to the spawnWave function, but it may differ for spawners that have animations.
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
function spawnWaveSilent(waveSpawners)
  local monsterIds = {}

  -- Spawn the monsters
  -- For each monster spawner in the wave...
  for _, monster in ipairs(waveSpawners) do
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

--[[
  Activates the triggers in the current wave. Returns a list of the monsters spawned.
  waveTriggers: A table with the following schema:
    {
      {
        Rect queryArea: the area to query for targets
        Json queryOptions: the options to use when querying the targets
        String messageType: message type to send
        LuaValue List messageArgs: the arguments to give
      }
    }
  returns: a list of the IDs of the monsters spawned
]]
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

  -- For each trigger in the wave...
  for _, trigger in ipairs(waveTriggers) do
    if trigger.messageType and trigger.messageType ~= "" then
      -- Query the targets
      local points = vEntity.getRegionPoints(trigger.queryArea)
      local targets = world.entityQuery(points[1], points[2], trigger.queryOptions)
      -- sb.logInfo("Activating trigger: %s", trigger)

      -- Make the trigger send the messages (no error handler this time).
      vWorldA.sendEntityMessageToTargets(triggerSuccessHandler, function() end, targets, trigger.messageType,
          table.unpack(trigger.messageArgs))

      if trigger.delay > 0 then
        util.wait(trigger.delay)
      end
    end
  end

  return monsterIds
end

---Resets all the triggers for the current wave and resets the triggers for the previous waves that are configured to be
---reset on subsequent waves.
---@param waveNum integer a number between 1 and `#storage.waves`
function resetTriggers(waveNum)
  -- For all waves up to (but not including) waveNum...
  for i = 1, waveNum - 1 do
    local wave = storage.waves[i]

    -- For each trigger in the wave...
    for _, trigger in ipairs(wave.triggers) do
      -- If the trigger resets on subsequent waves...
      if trigger.resetOnSubsequentWaves then
        -- Query the targets
        local points = vEntity.getRegionPoints(trigger.queryArea)
        local targets = world.entityQuery(points[1], points[2], trigger.queryOptions)

        -- Send the messages
        for _, target in ipairs(targets) do
          vWorld.sendEntityMessage(target, "v-monsterwavespawner-reset")
        end
      end
    end
  end

  local wave = storage.waves[waveNum]
  -- Tell all trigger targets in the current wave to reset.
  for _, trigger in ipairs(wave.triggers) do
    -- Query the targets
    local points = vEntity.getRegionPoints(trigger.queryArea)
    local targets = world.entityQuery(points[1], points[2], trigger.queryOptions)

    -- Send the messages
    for _, target in ipairs(targets) do
      vWorld.sendEntityMessage(target, "v-monsterwavespawner-reset")
    end
  end
end

function deactivateTriggers()
  -- For all waves...
  for i = 1, #storage.waves do
    local wave = storage.waves[i]

    -- For each trigger in the wave...
    for _, trigger in ipairs(wave.triggers) do
      -- If the trigger deactivates on completion...
      if trigger.deactivateOnCompletion then
        -- Query the targets
        local points = vEntity.getRegionPoints(trigger.queryArea)
        local targets = world.entityQuery(points[1], points[2], trigger.queryOptions)

        -- Send the messages
        for _, target in ipairs(targets) do
          vWorld.sendEntityMessage(target, "v-monsterwavespawner-deactivate")
        end
      end
    end
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
  If the room was not cleared, opens one door, leaves the other closed, and waits for friendlies to enter. Otherwise,
  opens all doors and never activates again.

  If an input node is connected and it is not active, it leaves all doors open instead.
]]
function reset()
  object.setOutputNodeLevel(0, true)

  if storage.active then
    object.setOutputNodeLevel(1, not storage.hasActiveInput)
    state:set(states.postInit)
  else
    object.setOutputNodeLevel(1, true)
    state:set(states.inactive)
  end

  -- Well this seems to disable the message.
  message.setHandler("v-monsterwavespawner-monsterspawned", nil)

  object.setInteractive(false)  -- Set interactive to false in case the spawner reset during the grace period.
end

-- HELPER FUNCTIONS
--[[
  Helper function. Logs an error from a promise.
]]
function _errorHandler(msg)
  return function(promise) sb.logError("%s: %s", msg, promise:error()) end
end

-- HOOKS (may use stubs by default)

--[[
  A function called once the object finishes loading the waves or on a reset.
]]
function onLoad()

end

--[[
  A function called once the object starts receiving input.
]]
function onInputActivation()
end

--[[
  A function called immediately after activation.
]]
function onActivation()
end

--[[
  A function called right before the waves are iterated through
]]
function onWavesStart()

end

--[[
  A function called for each tick spent while a wave is in progress.

  param waveNum: the current wave number
  param dt: tick duration
]]
function onWaveTick(waveNum, dt)

end

--[[
  A function called when a wave ends.
]]
function onWaveEnd(waveNum)

end

--[[
  A function called when the object enters the "inactive" state.
]]
function onDeactivation()

end

--[[
  A function called when the object enters a grace period prior to the waves starting. This function is called before
  onWavesStart() is called. The grace period will always start after the spawner resets itself due to friendlies
  leaving the area (by any means) at least once.
]]
function onGracePeriodStart()

end

--[[
  A function called each tick while the spawner is in the grace period.

  param dt: tick duration
]]
function onGracePeriodTick(dt)

end