require "/scripts/vec2.lua"

local disappearTime
local projectileParameters

local lightRingInterval
local lightRingProjectileType
local lightRingProjectileCount

local lightRingTimer

local shouldDieVar

function init()
  disappearTime = config.getParameter("disappearTime")
  projectileParameters = config.getParameter("projectileParameters")

  lightRingInterval = 10
  lightRingProjectileType = "v-riftremnantlight"
  lightRingProjectileCount = 20

  lightRingTimer = lightRingInterval
end

function update(dt)
  if disappearTime and world.time() > disappearTime then
    monster.setDropPool(nil)
    shouldDieVar = true
  end

  if status.resource("health") <= 0.0 then
    shouldDieVar = true
  end
  -- lightRingTimer = lightRingTimer - dt

  -- if lightRingTimer <= 0 then
  --   for i = 0, lightRingProjectileCount do
  --     local angle = i / lightRingProjectileCount * 2 * math.pi

  --     world.spawnProjectile(lightRingProjectileType, mcontroller.position(), entity.id(), vec2.withAngle(angle))
  --   end
  --   lightRingTimer = lightRingInterval
  -- end
end

function shouldDie()
  return shouldDieVar
end

function die()
  world.spawnProjectile("v-proxyprojectile", mcontroller.position(), entity.id(), {0, 0}, false, projectileParameters)
end

function uninit()
  if not shouldDieVar then
    world.sendEntityMessage("v-riftzonemanager-stagehand", "pushRiftRemnant", {
      position = mcontroller.position(),
      disappearTime = disappearTime
    })
  end
end