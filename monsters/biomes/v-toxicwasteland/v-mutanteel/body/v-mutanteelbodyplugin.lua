require "/scripts/util.lua"
require "/scripts/voidedattackutil.lua"

local oldInit = init or function() end
local oldUpdate = update or function() end

local windupTime
local projectileType
local projectileParameters
local projectileOffset

function init()
  oldInit()
  
  windupTime = config.getParameter("windupTime")
  projectileType = config.getParameter("projectileType")
  projectileParameters = config.getParameter("projectileParameters", {})
  projectileParameters.power = v_scaledPower(projectileParameters.power or 10)
  projectileOffset = config.getParameter("projectileOffset", {0, 0})

  message.setHandler("v-wormFire", function(_, _, numSegments, targetId)
    if numSegments > 0 then
      world.sendEntityMessage(self.childId, "v-wormFire", numSegments - 1, targetId)
    else
      state:set(states.fire, targetId)
    end
  end)
  
  state = FSM:new()
  state:set(states.noop)
end

function update(dt)
  oldUpdate(dt)
  
  state:update()
end

states = {}

function states.noop()
  while true do
    coroutine.yield()
  end
end

function states.fire(targetId)
  animator.setAnimationState("body", "windup")
  
  util.wait(windupTime)
  
  if not world.entityExists(targetId) then
    state:set(states.noop)
    coroutine.yield()
  end
  
  local targetVector = vec2.norm(world.distance(world.entityPosition(targetId), mcontroller.position()))
  world.spawnProjectile(
    projectileType,
    vec2.add(mcontroller.position(), projectileOffset),
    entity.id(),
    targetVector,
    false,
    projectileParameters
  )
  
  animator.setAnimationState("body", "fire")
  animator.playSound("fire")
  
  state:set(states.noop)
end