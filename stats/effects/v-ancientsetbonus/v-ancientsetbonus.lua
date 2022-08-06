require "/scripts/util.lua"

function init()
  -- Initialize parameters
  self.level = config.getParameter("level")
  self.spawnInterval = config.getParameter("spawnInterval")
  self.maxCount = config.getParameter("maxCount")
  self.orbiterTypes = config.getParameter("orbiterTypes")
  self.attackRange = config.getParameter("attackRange")
  self.orbiterConfig = config.getParameter("orbiterConfig")
  self.orbiterConfig.power = (self.orbiterConfig.power or 10) * root.evalFunction("weaponDamageLevelMultiplier", self.level)

  -- Initialize variables
  self.tickTimer = self.spawnInterval
  self.orbiters = {}
end

function update(dt)
  self.tickTimer = self.tickTimer - dt
  
  if self.tickTimer <= 0 and #self.orbiters < self.maxCount then
    addOrbiter()
  end
  
  local pos = mcontroller.position()
  local queried = world.entityQuery(pos, self.attackRange, {includedTypes = {"creature"}, order = "nearest"})
  for _, entity in ipairs(queried) do
    if validTarget(pos, entity) then
      fireOrbiters(entity)
      break
    end
  end
end

function fireOrbiters(target)
  for _, orbiter in ipairs(self.orbiters) do
    world.sendEntityMessage(orbiter, "kill", target)
  end
  self.orbiters = {}
end

function validTarget(pos, x)
  local entityPos = world.nearestTo(pos, world.entityPosition(x))  -- Fix extreme lag near world edges
  return world.entityExists(x) and not world.lineCollision(pos, entityPos) and entity.isValidTarget(x)
end

function addOrbiter()
  for i, orbiter in ipairs(self.orbiters) do
    local angleOffset = 2 * math.pi * i / (#self.orbiters + 1)
    world.sendEntityMessage(orbiter, "reset", angleOffset)
  end

  local orbiterId = world.spawnProjectile(util.randomFromList(self.orbiterTypes), mcontroller.position(), entity.id(), {0, 0}, false, self.orbiterConfig)
  table.insert(self.orbiters, orbiterId)
  
  self.tickTimer = self.spawnInterval
end

function onExpire()
  for _, orbiter in ipairs(self.orbiters) do
    world.sendEntityMessage(orbiter, "kill")
  end
end