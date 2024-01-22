require "/scripts/vec2.lua"
require "/scripts/util.lua"
require "/scripts/rect.lua"

local gasEmissionInterval
local onDuration
local offDuration

local gasProjectileType
local gasProjectileConfig

local gasDirection
local gasOffset

local requiredEmptySpace

local state

function init()
  gasEmissionInterval = config.getParameter("gasEmissionInterval")
  onDuration = config.getParameter("onDuration")
  offDuration = config.getParameter("offDuration")
  
  gasProjectileType = config.getParameter("gasProjectileType")
  gasProjectileConfig = config.getParameter("gasProjectileConfig")
  
  gasDirection = config.getParameter("gasDirection")
  gasOffsetRegion = config.getParameter("gasOffsetRegion")
  
  requiredEmptySpace = rect.translate(config.getParameter("requiredEmptySpace"), object.position())
  
  state = FSM:new()
  state:set(postInit)
end

function update(dt)
  state:update()
end

function postInit()
  -- Skip if collision has already been checked
  if storage.checkedCollision then
    state:set(inactive)
  end

  -- While the region to check has not fully loaded, wait one tick.
  while not world.regionActive(requiredEmptySpace) do
    coroutine.yield()
  end
  
  -- If the required empty space is not given, die instantly.
  if world.rectCollision(requiredEmptySpace) then
    object.smash(true)
  end
  
  storage.checkedCollision = true
  
  state:set(inactive)
end

function inactive()
  util.wait(offDuration)
  
  state:set(active)
end

function active()
  local timer = gasEmissionInterval
  
  animator.playSound("gasEmitterStart")
  animator.playSound("gasEmitterLoop", -1)
  
  util.wait(onDuration, function(dt)
    timer = timer - dt
    
    if timer <= 0 then
      world.spawnProjectile(gasProjectileType, vec2.add(object.position(), rect.randomPoint(gasOffsetRegion)), 
          entity.id(), gasDirection, false, gasProjectileConfig)
      timer = gasEmissionInterval
    end
  end)
  
  animator.stopAllSounds("gasEmitterLoop")
  animator.playSound("gasEmitterStop")
  
  state:set(inactive)
end