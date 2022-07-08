require "/scripts/util.lua"
require "/scripts/vec2.lua"

function init()
  self.warningRange = config.getParameter("warningRange")
  self.dischargeRange = config.getParameter("dischargeRange")
  self.dischargeProjectile = config.getParameter("dischargeProjectile")
  if not self.dischargeProjectile.config then
    self.dischargeProjectile.config = {}
  end
  self.dischargeProjectile.config.power = (self.dischargeProjectile.config.power or 10) * root.evalFunction("monsterLevelPowerMultiplier", monster.level())
  self.cooldownTime = config.getParameter("cooldownTime")
  self.warningTime = config.getParameter("warningTime")
  
  monster.setAnimationParameter("animationConfig", config.getParameter("animationConfig"))
  monster.setDeathParticleBurst("deathPoof")

  if animator.hasSound("deathPuff") then
    monster.setDeathSound("deathPuff")
  end

  message.setHandler("despawn", despawn)
  
  self.target = nil

  self.state = FSM:new()
  self.state:set(states.targeting)
end

function update(dt)
  self.state:update()
  monster.setAnimationParameter("warningVectors", self.warningParams)
  self.warningParams = {}
  monster.setAnimationParameter("ownPosition", mcontroller.position())
end

states = {}

function states.targeting()
  animator.setAnimationState("body", "active")

  while not self.target do
    local ownPosition = mcontroller.position()
    local queried = world.entityQuery(ownPosition, self.warningRange, {includedTypes = {"creature"}, withoutEntityId = entity.id()})
    local warningParams = {}
    queried = util.filter(queried, function(x)
      return entity.isValidTarget(x)
    end)
    for _, entityId in ipairs(queried) do
      local entityPos = world.entityPosition(entityId)
      local distance = world.magnitude(ownPosition, entityPos)
      local angle = vec2.angle(world.distance(entityPos, ownPosition))
      table.insert(warningParams, {distance, angle})
      if distance < self.dischargeRange then
        self.target = entityId
        break
      end
    end
    self.warningParams = warningParams
    coroutine.yield()
  end
  
  self.state:set(states.discharge)
end

function states.discharge()
  animator.setAnimationState("body", "discharge")
  if world.entityExists(self.target) then
    world.spawnProjectile(self.dischargeProjectile.type, world.entityPosition(self.target), entity.id(), {0, 0}, false, self.dischargeProjectile.config)
  end
  self.target = nil
  
  self.state:set(states.cooldown)
end

function states.cooldown()
  util.wait(self.cooldownTime)
  
  animator.setAnimationState("body", "warning")
  util.wait(self.warningTime)
  
  self.state:set(states.targeting)
end