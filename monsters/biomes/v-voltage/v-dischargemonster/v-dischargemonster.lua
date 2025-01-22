require "/scripts/util.lua"
require "/scripts/vec2.lua"
require "/scripts/v-animator.lua"
require "/scripts/companions/capturable.lua"

local warningRange
local dischargeRange
local dischargeProjectileType
local dischargeProjectileParameters
local cooldownTime
local initialCooldownTime
local warningTime
local lightningConfig

local warningParams
local target
local attackState

function init()
  script.setUpdateDelta(config.getParameter("updateDelta", 1))

  warningRange = config.getParameter("warningRange")
  dischargeRange = config.getParameter("dischargeRange")
  dischargeProjectileType = config.getParameter("dischargeProjectileType")
  dischargeProjectileParameters = config.getParameter("dischargeProjectileParameters", {})
  dischargeProjectileParameters.power = (dischargeProjectileParameters.power or 10) * root.evalFunction("monsterLevelPowerMultiplier", monster.level())
  cooldownTime = config.getParameter("cooldownTime")
  initialCooldownTime = config.getParameter("initialCooldownTime")
  dischargeTime = config.getParameter("dischargeTime")
  warningTime = config.getParameter("warningTime")
  lightningConfig = config.getParameter("lightningConfig")
  initialVelocity = config.getParameter("initialVelocity")

  monster.setAnimationParameter("animationConfig", config.getParameter("animationConfig"))
  monster.setDeathParticleBurst("deathPoof")

  if animator.hasSound("deathPuff") then
    monster.setDeathSound("deathPuff")
  end

  monster.setAggressive(true)
  message.setHandler("despawn", despawn)

  capturable.init()

  target = nil

  warningParams = {}
  attackState = FSM:new()
  attackState:set(states.initialCooldown)

  -- If initialVelocity is defined, use it.
  if initialVelocity then
    mcontroller.setVelocity(initialVelocity)
  end
end

function update(dt)
  local isStunned = status.resourcePositive("stunned")

  animator.setAnimationState("damage", isStunned and "stunned" or "none")

  if not isStunned then
    attackState:update()
  end

  -- Update animation parameters
  monster.setAnimationParameter("warningVectors", warningParams)
  monster.setAnimationParameter("ownPosition", mcontroller.position())

  -- Reset warningParams
  warningParams = {}

  if not isStunned then
    capturable.update(dt)
    updateVelocity()
    mcontroller.controlDown()  -- Go through platforms
  end
end

function die()
  -- Handle capturable dying
  capturable.die()
end

function shouldDie()
  -- Modified to return true if out of health or captured.
  return status.resource("health") <= 0 or capturable.justCaptured
end

states = {}

function states.targeting()
  animator.setAnimationState("body", "active")

  while not target do
    local ownPosition = mcontroller.position()

    -- Get initial targets by querying and filtering by whether or not they are valid.
    local queried = world.entityQuery(ownPosition, warningRange, {includedTypes = {"creature"}, withoutEntityId = entity.id()})
    queried = util.filter(queried, function(x)
      return entity.isValidTarget(x)
    end)

    -- Loop through initial targets
    for _, entityId in ipairs(queried) do
      local entityPos = world.entityPosition(entityId)
      local distance = world.magnitude(ownPosition, entityPos)
      local angle = vec2.angle(world.distance(entityPos, ownPosition))
      if warningParams then
        -- This line could be reached before update() is even called.
        table.insert(warningParams, {distance, angle})
      end
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
  animator.playSound("discharge")

  if world.entityExists(target) then
    local ownPosition = mcontroller.position()
    local targetPos = world.nearestTo(ownPosition, world.entityPosition(target))
    world.spawnProjectile(dischargeProjectileType, targetPos, entity.id(), {0, 0}, false, dischargeProjectileParameters)

    local timer = 0
    util.wait(dischargeTime, function(dt)
      drawLightning(timer / dischargeTime, ownPosition, targetPos)
      timer = timer + dt
    end)
  end

  monster.setAnimationParameter("lightning", {})
  target = nil

  attackState:set(states.cooldown)
end

function states.cooldown()
  util.wait(cooldownTime)

  attackState:set(states.warning)
end

function states.initialCooldown()
  animator.setAnimationState("body", "inactive")

  util.wait(initialCooldownTime)

  attackState:set(states.warning)
end

function states.warning()
  animator.setAnimationState("body", "warning")
  util.wait(warningTime)

  attackState:set(states.targeting)
end

--[[
  Draws lightning with a specific color progress from startPos to endPos.
  progress: How close to the end value the color of the lightning should be
  startPos: The starting absolute position of the lightning
  endPos: The ending absolute position of the lightning
]]
function drawLightning(progress, startPos, endPos)
  local cfgCopy = copy(lightningConfig)

  cfgCopy.color = vAnimator.lerpColor(progress, lightningConfig.startColor, lightningConfig.endColor)
  cfgCopy.worldStartPosition = startPos
  cfgCopy.worldEndPosition = endPos

  monster.setAnimationParameter("lightning", {cfgCopy})
end

--[[
  Updates the velocity of the entity so that it always attempts to travel at the configured flySpeed (and is influenced
  by external forces). If the speed is precisely 0, it will choose a random direction.
]]
function updateVelocity()
  local params = mcontroller.baseParameters()
  local velocityDirection = vec2.norm(mcontroller.velocity())

  -- If speed is not zero...
  if vec2.mag(mcontroller.velocity()) ~= 0 then
    -- Try to travel at the target speed without changing direction.
    local velocityDirection = vec2.norm(mcontroller.velocity())
    mcontroller.controlApproachVelocity(vec2.mul(velocityDirection, params.flySpeed), params.airForce)
  else
    -- Impart random velocity
    local velocity = vec2.withAngle(util.randomInRange({0, 2 * math.pi}), params.flySpeed)
    mcontroller.controlApproachVelocity(velocity, params.airForce)
  end
end

function despawn()
  monster.setDropPool(nil)
  monster.setDeathParticleBurst(nil)
  monster.setDeathSound(nil)
  status.addEphemeralEffect("monsterdespawn")
end