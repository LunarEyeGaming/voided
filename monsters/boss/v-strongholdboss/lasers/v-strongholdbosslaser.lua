require "/scripts/util.lua"
require "/scripts/vec2.lua"
require "/scripts/rect.lua"

local moveState
local attackState
local speed
local controlForce
local tolerance
local pulseDuration
local teleDuration
local windupDuration
local winddownDuration
local masterId
local sticky
local explosionSpecs
local spawnPos

local HORIZONTAL = 0
local VERTICAL = 1

function init()
  moveState = FSM:new()
  attackState = FSM:new()

  speed = config.getParameter("speed")
  controlForce = config.getParameter("controlForce")
  tolerance = config.getParameter("tolerance")

  pulseDuration = config.getParameter("pulseDuration")
  teleDuration = config.getParameter("teleDuration")
  windupDuration = config.getParameter("windupDuration")
  winddownDuration = config.getParameter("winddownDuration")

  masterId = config.getParameter("masterId")
  sticky = config.getParameter("sticky")  -- 0 = horizontal, 1 = vertical; determines which axis to lock
  explosionSpecs = config.getParameter("explosionSpecs")

  monster.setDamageBar(config.getParameter("damageBar"))
  
  spawnPos = mcontroller.position()

  if config.getParameter("uniqueId") then
    monster.setUniqueId(config.getParameter("uniqueId"))
  end
  if animator.hasSound("deathPuff") then
    monster.setDeathSound("deathPuff")
  end

  message.setHandler("despawn", despawn)

  message.setHandler("move", function(_, _, pos)
    moveState:set(states.move, pos)
  end)

  message.setHandler("moveandpulse", function(_, _, pos)
    moveState:set(states.moveAndPulse, pos)
  end)
  
  message.setHandler("reset", function()
    moveState:set(states.reset)
  end)
  
  message.setHandler("activate", function()
    attackState:set(states.activate)
  end)
  
  message.setHandler("deactivate", function()
    attackState:set(states.deactivate)
  end)
  
  message.setHandler("pulse", function()
    attackState:set(states.pulse)
  end)
  
  message.setHandler("explode", explode)
end

function shouldDie()
  return not status.resourcePositive("health")
end

function update(dt)
  moveState:update()
  attackState:update()
end

-- STATES
states = {}

function states.noop()
  while true do
    coroutine.yield()
  end
end

function states.move(pos)
  activatePad()
  flyToPos(clampPos(pos))
  notifySource("finished")
  states.noop()
end

function states.moveAndPulse(pos)
  activatePad()
  flyToPos(clampPos(pos))
  states.pulse()
end

function states.activate()
  util.wait(teleDuration)

  animator.setAnimationState("pad", "windup")
  animator.setAnimationState("laser", "windup")
  animator.playSound("windup")
  util.wait(windupDuration)

  animator.playSound("fire")
  animator.setAnimationState("laser", "active")
  monster.setDamageOnTouch(true)
  animator.playSound("loop", -1)
  
  notifySource("finished")
  states.noop()
end

function states.deactivate()
  animator.stopAllSounds("loop")
  animator.setAnimationState("laser", "winddown")
  animator.playSound("fireend")
  monster.setDamageOnTouch(false)
  
  animator.setAnimationState("pad", "winddown")
  
  util.wait(winddownDuration)
  
  notifySource("finished")
  states.noop()
end

function states.pulse()
  util.wait(teleDuration)

  animator.setAnimationState("pad", "windup")
  animator.setAnimationState("laser", "windup")
  animator.playSound("windup")
  util.wait(windupDuration)

  animator.setAnimationState("laser", "active")
  monster.setDamageOnTouch(true)

  animator.playSound("fire")
  util.wait(pulseDuration)

  animator.setAnimationState("laser", "winddown")
  animator.playSound("fireend")
  monster.setDamageOnTouch(false)
  
  animator.setAnimationState("pad", "winddown")
  
  util.wait(winddownDuration)
  
  notifySource("finished")
  states.noop()
end

function states.reset()
  attackState:set(states.noop)

  animator.setAnimationState("laser", "inactive")
  animator.stopAllSounds("loop")
  monster.setDamageOnTouch(false)

  flyToPos(spawnPos)

  animator.setAnimationState("pad", "deactivate")
  notifySource("finished")

  states.noop()
end

-- HELPER FUNCTIONS
function activatePad()
  local padState = animator.animationState("pad")
  if padState ~= "active" and padState ~= "windup" then
    animator.setAnimationState("pad", "activate")
  end
end

function clampPos(pos)
  if sticky == HORIZONTAL then
    return {spawnPos[1], pos[2]}
  elseif sticky == VERTICAL then
    return {pos[1], spawnPos[2]}
  end
end

function flyToPos(pos)
  local distance
  repeat
    distance = world.distance(pos, mcontroller.position())
    mcontroller.controlApproachVelocity(vec2.mul(vec2.norm(distance), speed), controlForce)
    coroutine.yield()
  until math.abs(distance[1]) < tolerance and math.abs(distance[2]) < tolerance
  
  mcontroller.setVelocity({0, 0})
  mcontroller.setPosition(pos)
end

function notifySource(msg)
  local notification = {
    sourceId = entity.id(),
    type = msg
  }
  world.sendEntityMessage(masterId, "notify", notification)
end

function explode()
  for i = 1, explosionSpecs.count do
    local offset = rect.randomPoint(explosionSpecs.offsetRegion)
    world.spawnProjectile(explosionSpecs.projectileType, vec2.add(mcontroller.position(), offset), entity.id(), {0, 0}, false, explosionSpecs.projectileConfig)
  end
  animator.setAnimationState("pad", "destroyed")
end

function despawn()
  monster.setDropPool(nil)
  monster.setDeathParticleBurst(nil)
  monster.setDeathSound(nil)
  status.addEphemeralEffect("monsterdespawn")
end