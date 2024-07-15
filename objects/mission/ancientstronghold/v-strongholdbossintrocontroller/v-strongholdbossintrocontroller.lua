--[[
  A script that controls the intro for the Prison. The following is the sequence of events that this script goes 
  through:
    * Waits for a player to enter lightsRegion.
    * Activates the row of lights one by one first (time between each one specified by bottomLightInterval). Uses
      BOTTOM_LIGHT_OUTPUT_NODES to do this.
    * After spotlightDelay seconds, activates the spotlights at the end (by activating SPOTLIGHT_OUTPUT_NODE).
    * If a player enters trapRegion at any point after a player enters lightsRegion, the row of lights deactivates, an
      alarm light is activated (by activating ALARM_LIGHT_OUTPUT_NODE), the back doors are closed (by deactivating
      BACKDOOR_OUTPUT_NODE), and the spotlights are activated immediately if they haven't been already.
    * After doorCloseDelay seconds, the doors on the sides close (by deactivating DOOR_OUTPUT_NODE), and the alarm light
      node deactivates.
    * After arenaRevealDelay seconds, the floor and ceiling open, and the lights turn on (by activating
      ARENA_REVEAL_OUTPUT_NODE).
    * From here on out, if no players are present in arenaRegion for resetDelay seconds, everything resets. However, if
      the boss is defeated, DOOR_OUTPUT_NODE is activated, TURRET_OUTPUT_NODE is deactivated, and the object does 
      nothing forever (using storage.bossDefeated).
]]

require "/scripts/util.lua"
require "/scripts/rect.lua"

local BOTTOM_LIGHT_OUTPUT_NODES = {0, 1, 2, 3}
local SPOTLIGHT_OUTPUT_NODE = 4
local ALARM_LIGHT_OUTPUT_NODE = 5
local BACKDOOR_OUTPUT_NODE = 6
local DOOR_OUTPUT_NODE = 7
local ARENA_REVEAL_OUTPUT_NODE = 8
local TURRET_OUTPUT_NODE = 9

local controllerState

local lightsRegion
local trapRegion
local arenaRegion

local bottomLightInterval
local spotlightDelay
local doorCloseDelay
local arenaRevealDelay
local resetDelay

local bossUniqueId

function init()
  lightsRegion = getRegionPoints(config.getParameter("lightsRegion"))
  trapRegion = getRegionPoints(config.getParameter("trapRegion"))
  arenaRegion = getRegionPoints(config.getParameter("arenaRegion"))
  
  bottomLightInterval = config.getParameter("bottomLightInterval")
  spotlightDelay = config.getParameter("spotlightDelay")
  doorCloseDelay = config.getParameter("doorCloseDelay")
  arenaRevealDelay = config.getParameter("arenaRevealDelay")
  resetDelay = config.getParameter("resetDelay")
  
  bossUniqueId = config.getParameter("bossUniqueId")
  
  util.setDebug(true)

  controllerState = FSM:new()
  
  if not storage.bossDefeated then
    initializeNodes()
    controllerState:set(states.phase1Wait)
  else
    controllerState:set(states.noop)
  end
end

function update(dt)
  controllerState:update()
  
  util.debugRect(rect.translate(config.getParameter("lightsRegion"), object.position()), "green")
  util.debugRect(rect.translate(config.getParameter("trapRegion"), object.position()), "green")
  util.debugRect(rect.translate(config.getParameter("arenaRegion"), object.position()), "green")
end

-- *****************************************
-- *************STATE FUNCTIONS*************
-- *****************************************

states = {}

--[[
  Waits for a player to enter lightsRegion before transitioning to phase1.
]]
function states.phase1Wait()
  while not playerInRegion(lightsRegion) do
    coroutine.yield()
  end
  
  controllerState:set(states.phase1)
end

--[[
  Activates floor lights and spotlight. If a player at any point enters trapRegion in this state, it is interrupted and
  immediately transitions to phase2. Otherwise, it transitions to phase2Wait.
]]
function states.phase1()
  -- A function to be run in each tick of util.wait. It interrupts the current state and transitions to phase2 if it
  -- finds a player inside trapRegion.
  local attemptPhase2Transition = function()
    if playerInRegion(trapRegion) then
      controllerState:set(states.phase2)
    end
  end

  -- For each node in BOTTOM_LIGHT_OUTPUT_NODES...
  for _, node in ipairs(BOTTOM_LIGHT_OUTPUT_NODES) do
    util.wait(bottomLightInterval, attemptPhase2Transition)

    object.setOutputNodeLevel(node, true)
  end
  
  util.wait(spotlightDelay, attemptPhase2Transition)
  
  object.setOutputNodeLevel(SPOTLIGHT_OUTPUT_NODE, true)
  
  controllerState:set(states.phase2Wait)
end

--[[
  Waits for a player to enter trapRegion before transitioning to phase 2.
]]
function states.phase2Wait()
  while not playerInRegion(trapRegion) do
    coroutine.yield()
  end
  
  controllerState:set(states.phase2)
end

--[[
  Deactivates the floor lights, activates an alarm light, activates the spotlights (if they aren't active already), 
  closes the backdoor, and then closes the doors (also deactivating the alarm light) before revealing the arena.
]]
function states.phase2()
  -- Go through each bottom light node and deactivate it.
  for _, node in ipairs(BOTTOM_LIGHT_OUTPUT_NODES) do
    object.setOutputNodeLevel(node, false)
  end
  
  object.setOutputNodeLevel(SPOTLIGHT_OUTPUT_NODE, true)  -- Immediately activate spotlight node if it isn't active
  object.setOutputNodeLevel(ALARM_LIGHT_OUTPUT_NODE, true)  -- Activate alarm light
  object.setOutputNodeLevel(BACKDOOR_OUTPUT_NODE, false)  -- Close the backdoor.
  
  util.wait(doorCloseDelay)
  
  object.setOutputNodeLevel(DOOR_OUTPUT_NODE, false)  -- Close doors
  object.setOutputNodeLevel(ALARM_LIGHT_OUTPUT_NODE, false)  -- Deactivate alarm light
  
  util.wait(arenaRevealDelay)
  
  object.setOutputNodeLevel(ARENA_REVEAL_OUTPUT_NODE, true)  -- Reveal the arena
  
  controllerState:set(states.phase3)
end

--[[
  Now it's a fight to the death. If no more players are present inside the arena, the object resets itself. If the boss
  is defeated (indicated by the boss with unique ID bossUniqueId no longer existing), the doors open, the turrets are
  deactivated, and the object permanently deactivates itself.
]]
function states.phase3()
  -- While the boss exists and at least one player is in the arena...
  while world.loadUniqueEntity(bossUniqueId) ~= 0 and playerInRegion(arenaRegion) do
    coroutine.yield()
  end
  
  -- If the boss was defeated...
  if world.loadUniqueEntity(bossUniqueId) == 0 then
    object.setOutputNodeLevel(DOOR_OUTPUT_NODE, true)  -- Open doors
    object.setOutputNodeLevel(BACKDOOR_OUTPUT_NODE, true)  -- Open backdoor
    object.setOutputNodeLevel(TURRET_OUTPUT_NODE, false)  -- Deactivate turrets
    
    storage.bossDefeated = true  -- Permanently deactivate object
  
    controllerState:set(states.noop)
  else
    initializeNodes()

    controllerState:set(states.phase1Wait)
  end
end

--[[
  Does nothing forever.
]]
function states.noop()
  while true do
    coroutine.yield()
  end
end

-- **************************************************
-- *****************HELPER FUNCTIONS*****************
-- **************************************************

--[[
  Converts a relative rectangle into a table of the bottom-left and top-right points (absolute) and returns the result.
]]
function getRegionPoints(rectangle)
  local absoluteRectangle = rect.translate(rectangle, object.position())
  
  return {rect.ll(absoluteRectangle), rect.ur(absoluteRectangle)}
end

--[[
  Returns true if at least one player is inside the given region and false otherwise.
  
  region: A pair of Vec2F's
]]
function playerInRegion(region)
  return #world.entityQuery(region[1], region[2], {includedTypes = {"player"}}) > 0
end

--[[
  Sets the states of the wires to their defaults. The default state is that all the lights are off, the doors are open,
  the arena is in disguise mode (arena reveal node is off), and the turrets are active.
]]
function initializeNodes()
  -- Go through each bottom light node and deactivate it.
  for _, node in ipairs(BOTTOM_LIGHT_OUTPUT_NODES) do
    object.setOutputNodeLevel(node, false)
  end
  
  object.setOutputNodeLevel(SPOTLIGHT_OUTPUT_NODE, false)
  object.setOutputNodeLevel(ALARM_LIGHT_OUTPUT_NODE, false)
  object.setOutputNodeLevel(BACKDOOR_OUTPUT_NODE, true)
  object.setOutputNodeLevel(DOOR_OUTPUT_NODE, true)
  object.setOutputNodeLevel(ARENA_REVEAL_OUTPUT_NODE, false)
  object.setOutputNodeLevel(TURRET_OUTPUT_NODE, true)
end