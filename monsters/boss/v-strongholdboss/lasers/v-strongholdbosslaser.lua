require "/scripts/util.lua"
require "/scripts/vec2.lua"
require "/scripts/rect.lua"

function init()
  self.moveState = FSM:new()
  self.attackState = FSM:new()

  self.speed = 40
  self.controlForce = 350
  self.posME = {0.5, 0.5}
  self.pulseDuration = 0.25
  self.teleDuration = 0.5
  self.windupDuration = 0.5
  self.winddownDuration = 0.4
  self.masterId = config.getParameter("masterId")
  HORIZONTAL = 0
  VERTICAL = 1
  self.sticky = config.getParameter("sticky")  -- 0 = horizontal, 1 = vertical; determines which axis to lock
  self.explosionSpecs = config.getParameter("explosionSpecs")
  monster.setDamageBar(config.getParameter("damageBar"))
  
  self.spawnPos = mcontroller.position()

  if config.getParameter("uniqueId") then
    monster.setUniqueId(config.getParameter("uniqueId"))
  end
  if animator.hasSound("deathPuff") then
    monster.setDeathSound("deathPuff")
  end

  message.setHandler("despawn", despawn)

  message.setHandler("move", function(_, _, pos)
    self.moveState:set(states.move, pos)
  end)

  message.setHandler("moveandpulse", function(_, _, pos)
    self.moveState:set(states.moveAndPulse, pos)
  end)
  
  message.setHandler("reset", function()
    self.moveState:set(states.reset)
  end)
  
  message.setHandler("activate", function()
    self.attackState:set(states.activate)
  end)
  
  message.setHandler("deactivate", function()
    self.attackState:set(states.deactivate)
  end)
  
  message.setHandler("pulse", function()
    self.attackState:set(states.pulse)
  end)
  
  message.setHandler("explode", explode)
end

function shouldDie()
  return not status.resourcePositive("health")
end

function update(dt)
  self.moveState:update()
  self.attackState:update()
end

-- STATES
states = {}

function states.noop()
  while true do
    coroutine.yield()
  end
end

function states.move(pos)
  _activate()
  _flyToPos(_clampPos(pos))
  _notifySource("finished")
  states.noop()
end

function states.moveAndPulse(pos)
  _activate()
  _flyToPos(_clampPos(pos))
  states.pulse()
end

function states.activate()
  util.wait(self.teleDuration)

  animator.setAnimationState("pad", "windup")
  animator.setAnimationState("laser", "windup")
  animator.playSound("windup")
  util.wait(self.windupDuration)

  animator.playSound("fire")
  animator.setAnimationState("laser", "active")
  monster.setDamageOnTouch(true)
  animator.playSound("loop", -1)
  
  _notifySource("finished")
  states.noop()
end

function states.deactivate()
  animator.stopAllSounds("loop")
  animator.setAnimationState("laser", "winddown")
  animator.playSound("fireend")
  monster.setDamageOnTouch(false)
  
  animator.setAnimationState("pad", "winddown")
  
  util.wait(self.winddownDuration)
  
  _notifySource("finished")
  states.noop()
end

function states.pulse()
  util.wait(self.teleDuration)

  animator.setAnimationState("pad", "windup")
  animator.setAnimationState("laser", "windup")
  animator.playSound("windup")
  util.wait(self.windupDuration)

  animator.setAnimationState("laser", "active")
  monster.setDamageOnTouch(true)

  animator.playSound("fire")
  util.wait(self.pulseDuration)

  animator.setAnimationState("laser", "winddown")
  animator.playSound("fireend")
  monster.setDamageOnTouch(false)
  
  animator.setAnimationState("pad", "winddown")
  
  util.wait(self.winddownDuration)
  
  _notifySource("finished")
  states.noop()
end

function states.reset()
  self.attackState:set(states.noop)
  animator.setAnimationState("laser", "inactive")
  animator.stopAllSounds("loop")
  monster.setDamageOnTouch(false)
  _flyToPos(self.spawnPos)
  animator.setAnimationState("pad", "deactivate")
  _notifySource("finished")
  states.noop()
end

-- HELPER FUNCTIONS
function _activate()
  local padState = animator.animationState("pad")
  if padState ~= "active" and padState ~= "windup" then
    animator.setAnimationState("pad", "activate")
  end
end

function _clampPos(pos)
  if self.sticky == HORIZONTAL then
    return {self.spawnPos[1], pos[2]}
  elseif self.sticky == VERTICAL then
    return {pos[1], self.spawnPos[2]}
  end
end

function _flyToPos(pos)
  local distance
  repeat
    distance = world.distance(pos, mcontroller.position())
    mcontroller.controlApproachVelocity(vec2.mul(vec2.norm(distance), self.speed), self.controlForce)
    coroutine.yield()
  until math.abs(distance[1]) < self.posME[1] and math.abs(distance[2]) < self.posME[2]
  
  mcontroller.setVelocity({0, 0})
  mcontroller.setPosition(pos)
end

function _notifySource(msg)
  local notification = {
    sourceId = entity.id(),
    type = msg
  }
  world.sendEntityMessage(self.masterId, "notify", notification)
end

function explode()
  for i = 1, self.explosionSpecs.count do
    local offset = rect.randomPoint(self.explosionSpecs.offsetRegion)
    world.spawnProjectile(self.explosionSpecs.projectileType, vec2.add(mcontroller.position(), offset), entity.id(), {0, 0}, false, self.explosionSpecs.projectileConfig)
  end
  animator.setAnimationState("pad", "destroyed")
end

function despawn()
  monster.setDropPool(nil)
  monster.setDeathParticleBurst(nil)
  monster.setDeathSound(nil)
  status.addEphemeralEffect("monsterdespawn")
end