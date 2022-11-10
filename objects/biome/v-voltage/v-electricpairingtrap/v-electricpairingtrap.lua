require "/scripts/util.lua"
require "/scripts/vec2.lua"
require "/scripts/voidedutil.lua"

-- script name: v-electricpairingtrap
local fireTime
local windupTime
local pairingRadius
local damageSourceConfig
local lightningConfig
local dischargeTime

local isPairable
local target
local ownPosition
local pairingPosition
local trapState

function init()
  fireTime = config.getParameter("cooldownTime")
  windupTime = config.getParameter("windupTime")
  pairingRadius = config.getParameter("pairingRadius")
  damageSourceConfig = config.getParameter("damageSourceConfig")
  damageSourceConfig.damage = (damageSourceConfig.damage or 10) * root.evalFunction("monsterLevelPowerMultiplier",
      object.level())
  lightningConfig = config.getParameter("lightningConfig")
  windupLightningConfig = config.getParameter("windupLightningConfig")
  dischargeTime = config.getParameter("dischargeTime")

  isPairable = true
  target = nil
  ownPosition = vec2.add(object.position(), config.getParameter("fireOffset", {0, 0}))

  trapState = FSM:new()
  trapState:set(states.wait)

  message.setHandler("becomePair", function()
    trapState:set(states.wait)
    return ownPosition
  end)
end

function update(dt)
  trapState:update()
end

states = {}

function states.wait()
  isPairable = true
  target = nil
  util.wait(util.randomInRange(fireTime))

  trapState:set(states.search)
end

function states.search()
  -- Attempt pairing with another pairing trap
  while not target do
    local queried = world.entityQuery(ownPosition, pairingRadius, {includedTypes = {"object"},
        withoutEntityId = entity.id(), callScript = "pairable", callScriptArgs = {ownPosition}, order = "random"})

    if #queried > 0 then
      target = queried[1]
    end

    coroutine.yield()
  end

  trapState:set(states.windup)
end

function states.windup()
  if not target or not world.entityExists(target) then
    target = nil
    trapState:set(states.search)
    coroutine.yield()
  end

  isPairable = false

  local promise = world.sendEntityMessage(target, "becomePair")
  util.await(promise)

  if not promise:succeeded() then
    trapState:set(states.search)
    coroutine.yield()
  end

  animator.playSound("windup")
  -- animator.setAnimationState("trap", "windup")

  pairingPosition = world.nearestTo(ownPosition, promise:result())

  local timer = 0
  util.wait(windupTime, function(dt)
    drawLightning(windupLightningConfig, timer / dischargeTime, ownPosition, pairingPosition)
    timer = timer + dt
  end)

  trapState:set(states.fire)
end

function states.fire()
  if not target or not world.entityExists(target) then
    trapState:set(states.search)
    coroutine.yield()
  end

  animator.playSound("fire")
  -- animator.setAnimationState("trap", "fire")

  local timer = 0
  util.wait(dischargeTime, function(dt)
    -- Brief damage arc
    if timer < 0.1 then
      setDamageArc(ownPosition, pairingPosition)
    else
      object.setDamageSources()
    end

    drawLightning(lightningConfig, timer / dischargeTime, ownPosition, pairingPosition)
    timer = timer + dt
  end)

  object.setAnimationParameter("lightning", {})

  trapState:set(states.wait)
end

--[[
  Returns true if there is no collision between the requester's position and the current object's position and the
  current object has not already paired with an existing trap.
  pos: The position of the requester
]]
function pairable(pos)
  local correctedPos = world.nearestTo(ownPosition, pos)
  return isPairable and not world.lineCollision(ownPosition, correctedPos)
end

--[[
  Sets the damage region to be a horizontal line with a starting absolute position of "from" and an ending absolute
  position of "to."

  from: The starting absolute position
  to: The ending absolute position
]]
function setDamageArc(from, to)
  local dmgCfg = copy(damageSourceConfig)
  local relativeFrom = world.distance(from, object.position())
  local relativeTo = world.distance(to, object.position())
  dmgCfg.poly = {relativeFrom, relativeTo}
  object.setDamageSources({dmgCfg})
end

--[[
  Draws lightning with a specific color progress from startPos to endPos.
  progress: How close to the end value each parameter of the lightning should be
  startPos: The starting absolute position of the lightning
  endPos: The ending absolute position of the lightning
]]
function drawLightning(cfg, progress, startPos, endPos)
  local cfgCopy = copy(cfg)

  cfgCopy.displacement = util.lerp(progress, cfg.startDisplacement, cfg.endDisplacement)
  cfgCopy.color = lerpColor(progress, cfg.startColor, cfg.endColor)
  cfgCopy.worldStartPosition = startPos
  cfgCopy.worldEndPosition = endPos

  object.setAnimationParameter("lightning", {cfgCopy})
end