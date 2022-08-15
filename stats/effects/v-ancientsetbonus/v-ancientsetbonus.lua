require "/scripts/util.lua"

local level
local spawnInterval
local maxCount
local orbiterTypes
local attackRange
local orbiterConfig
local tickTimer
local orbiters

function init()
  -- Initialize parameters
  level = config.getParameter("level")
  spawnInterval = config.getParameter("spawnInterval")
  maxCount = config.getParameter("maxCount")
  orbiterTypes = config.getParameter("orbiterTypes")
  attackRange = config.getParameter("attackRange")
  orbiterConfig = config.getParameter("orbiterConfig")
  orbiterConfig.power = (orbiterConfig.power or 10) * root.evalFunction("weaponDamageLevelMultiplier", level)

  -- Initialize variables
  tickTimer = spawnInterval
  orbiters = {}
end

function update(dt)
  tickTimer = tickTimer - dt
  
  if tickTimer <= 0 and #orbiters < maxCount then
    addOrbiter()
  end
  
  local pos = mcontroller.position()
  local queried = world.entityQuery(pos, attackRange, {includedTypes = {"creature"}, order = "nearest"})
  for _, entity in ipairs(queried) do
    if validTarget(pos, entity) then
      fireOrbiters(entity)
      break
    end
  end
end

function fireOrbiters(target)
  for _, orbiter in ipairs(orbiters) do
    world.sendEntityMessage(orbiter, "kill", target)
  end
  orbiters = {}
end

function validTarget(pos, x)
  local entityPos = world.nearestTo(pos, world.entityPosition(x))  -- Fix extreme lag near world edges
  return world.entityExists(x) and not world.lineCollision(pos, entityPos) and entity.isValidTarget(x)
end

function addOrbiter()
  for i, orbiter in ipairs(orbiters) do
    local angleOffset = 2 * math.pi * i / (#orbiters + 1)
    world.sendEntityMessage(orbiter, "reset", angleOffset)
  end

  local orbiterId = world.spawnProjectile(util.randomFromList(orbiterTypes), mcontroller.position(), entity.id(), {0, 0}, false, orbiterConfig)
  table.insert(orbiters, orbiterId)
  
  tickTimer = spawnInterval
end

function onExpire()
  for _, orbiter in ipairs(orbiters) do
    world.sendEntityMessage(orbiter, "kill")
  end
end