require "/scripts/util.lua"
require "/scripts/vec2.lua"

local warningRange
local dischargeRange
local dischargeProjectileType
local dischargeProjectileParameters
local cooldownTime
local warningTime
local warningParams
local target
local attackState

function init()
  warningRange = config.getParameter("warningRange")
  dischargeRange = config.getParameter("dischargeRange")
  dischargeProjectileType = config.getParameter("dischargeProjectileType")
  dischargeProjectileParameters = config.getParameter("dischargeProjectileParameters", {})
  dischargeProjectileParameters.power = (dischargeProjectileParameters.power or 10) * root.evalFunction("monsterLevelPowerMultiplier", monster.level())
  cooldownTime = config.getParameter("cooldownTime")
  warningTime = config.getParameter("warningTime")
  
  monster.setAnimationParameter("animationConfig", config.getParameter("animationConfig"))
  monster.setDeathParticleBurst("deathPoof")

  if animator.hasSound("deathPuff") then
    monster.setDeathSound("deathPuff")
  end

  message.setHandler("despawn", despawn)
  
  target = nil

  attackState = FSM:new()
  attackState:set(states.targeting)
end

function update(dt)
  attackState:update()
  monster.setAnimationParameter("warningVectors", warningParams)
  warningParams = {}
  monster.setAnimationParameter("ownPosition", mcontroller.position())
end

states = {}

function states.targeting()
  animator.setAnimationState("body", "active")

  while not target do
    local ownPosition = mcontroller.position()
    local queried = world.entityQuery(ownPosition, warningRange, {includedTypes = {"creature"}, withoutEntityId = entity.id()})
    queried = util.filter(queried, function(x)
      return entity.isValidTarget(x)
    end)
    for _, entityId in ipairs(queried) do
      local entityPos = world.entityPosition(entityId)
      local distance = world.magnitude(ownPosition, entityPos)
      local angle = vec2.angle(world.distance(entityPos, ownPosition))
      table.insert(warningParams, {distance, angle})
      if distance < dischargeRange then
        target = entityId
        break
      end
    end
    coroutine.yield()
  end
  
  attackState:set(states.discharge)
end

function states.discharge()
  animator.setAnimationState("body", "discharge")
  if world.entityExists(target) then
    world.spawnProjectile(dischargeProjectileType, world.entityPosition(target), entity.id(), {0, 0}, false, dischargeProjectileParameters)
  end
  target = nil
  
  attackState:set(states.cooldown)
end

function states.cooldown()
  util.wait(cooldownTime)
  
  animator.setAnimationState("body", "warning")
  util.wait(warningTime)
  
  attackState:set(states.targeting)
end