require "/scripts/vec2.lua"
require "/scripts/interp.lua"
require "/scripts/util.lua"
require "/scripts/v-animator.lua"

local followPlayer

local shouldDieVar
local lightningController
local state

function init()
  followPlayer = config.getParameter("masterId")

  shouldDieVar = false

  local cfg = config.getParameter("lightningConfig", {})

  lightningController = vAnimator.LightningController:new{
    cfg = cfg.baseConfig,
    startC = cfg.startColor,
    endC = cfg.endColor,
    dur = cfg.duration,
    animateManually = false,
    startOC = cfg.startOutlineColor,
    endOC = cfg.endOutlineColor,
  }

  monster.setDamageBar("None")
  state = FSM:new()
  state:set(states.postInit)
end

function update(dt)
  state:update(dt)

  lightningController:update(dt)

  local pos = world.entityPosition(followPlayer)
  if pos then
    mcontroller.setPosition(pos)
  end

  -- world.loadRegion(rect.translate({-32, -32, 32, 32}, mcontroller.position()))
end

states = {}

function states.postInit()
  for _ = 1, 2 do
    coroutine.yield()
  end

  state:set(states.main)
end

function states.main()
  world.spawnProjectile("v-proxyprojectile", mcontroller.position(), nil, nil, nil, {
    actionOnReap = {
      {
        action = "config",
        file = "/projectiles/unsorted/v-fissurecrossing/v-fissurecrossing.config"
      }
    }
  })

  util.wait(5.0)

  for _ = 1, 20 do
    crackleLightning(100)
    util.wait(0.2)
  end

  state:set(states.die)
end

function states.die()
  shouldDieVar = true

  -- The script should stop running within the next tick or two. This just ensures the coroutine doesn't die prematurely
  -- and cause an error.
  while true do
    coroutine.yield()
  end
end

function crackleLightning(radius)
  local randomPosStart = vec2.add(mcontroller.position(), vec2.withAngle(math.random() * 2 * math.pi, math.random() * radius))
  local randomPosEnd = vec2.add(mcontroller.position(), vec2.withAngle(math.random() * 2 * math.pi, math.random() * radius))

  lightningController:addRandomSeed(randomPosStart, randomPosEnd)

  animator.playSound("crackle")
end

function shouldDie()
  return shouldDieVar
end

function uninit()
end