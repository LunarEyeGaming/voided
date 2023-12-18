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

local state

function init()
  gasEmissionInterval = 0.2
  onDuration = 5
  offDuration = 5
  
  gasProjectileType = "v-poisoncloud"
  gasProjectileConfig = {}
  
  gasDirection = {0, 1}
  gasOffsetRegion = {-5, -5, 5, 5}
  
  state = FSM:new()
  state:set(inactive)
end

function update(dt)
  state:update()
end

function inactive()
  util.wait(offDuration)
  
  state:set(active)
end

function active()
  local timer = gasEmissionInterval
  
  util.wait(onDuration, function(dt)
    timer = timer - dt
    
    if timer <= 0 then
      world.spawnProjectile(gasProjectileType, vec2.add(object.position(), rect.randomPoint(gasOffsetRegion)), 
          entity.id(), gasDirection, false, gasProjectileConfig)
      timer = gasEmissionInterval
    end
  end)
  
  state:set(inactive)
end