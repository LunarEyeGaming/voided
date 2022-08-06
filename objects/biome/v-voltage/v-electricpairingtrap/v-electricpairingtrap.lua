require "/scripts/util.lua"
require "/scripts/vec2.lua"

-- script name: v-electricpairingtrap

function init()
  self.fireTime = config.getParameter("cooldownTime")
  self.windupTime = config.getParameter("windupTime")
  self.pairingRadius = config.getParameter("pairingRadius")
  self.projectileType = config.getParameter("projectileType")
  self.projectileParameters = config.getParameter("projectileParameters", {})
  self.projectileParameters.power = (self.projectileParameters.power or 10) * root.evalFunction("monsterLevelPowerMultiplier", object.level())
  
  self.pairable = true
  self.target = nil
  self.position = vec2.add(object.position(), config.getParameter("fireOffset", {0, 0}))
  
  self.state = FSM:new()
  self.state:set(states.wait)
  
  message.setHandler("windup", function()
    self.state:set(states.windup)
  end)
end

function update(dt)
  self.state:update()
end

states = {}

function states.wait()
  self.pairable = true
  self.target = nil
  util.wait(util.randomInRange(self.fireTime))
  
  self.state:set(states.search)
end

function states.search()
  -- Attempt pairing with another pairing trap
  while not self.target do
    local queried = world.entityQuery(self.position, self.pairingRadius, {includedTypes = {"object"}, withoutEntityId = entity.id(), callScript = "pairable"})
    queried = util.filter(queried, function(x)
      local entityPos = world.nearestTo(self.position, world.entityPosition(x))
      return not world.lineCollision(self.position, entityPos)
    end)

    if #queried > 0 then
      self.target = util.randomFromList(queried)
    end
    
    coroutine.yield()
  end

  self.state:set(states.windup)
end

function states.windup()
  if not self.target or not world.entityExists(self.target) then
    self.state:set(states.search)
    coroutine.yield()
  end

  self.pairable = false
  world.sendEntityMessage(self.target, "windup")
  
  -- animator.setAnimationState("trap", "windup")
  util.wait(self.windupTime)
  
  self.state:set(states.fire)
end

function states.fire()
  if not self.target or not world.entityExists(self.target) then
    self.state:set(states.search)
    coroutine.yield()
  end

  -- animator.setAnimationState("trap", "fire")
  
  world.spawnProjectile(self.projectileType, self.position, entity.id(), world.distance(world.entityPosition(self.target), self.position), false, self.projectileParameters)
  
  self.state:set(states.wait)
end

-- Callback function to determine if the current object queried is a pairing trap and is not active
function pairable()
  return self.pairable
end