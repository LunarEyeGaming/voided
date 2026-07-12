require "/scripts/vec2.lua"
require "/scripts/interp.lua"
require "/scripts/util.lua"
require "/scripts/v-animator.lua"

local followPlayer
local fissureCrossingProjectileType
local fissureCrossingProjectileParameters
local lightningStrikeSpecs
local postLightningWaitTime

local shouldDieVar
local lightningController
local state

function init()
  followPlayer = config.getParameter("masterId")
  fissureCrossingProjectileType = config.getParameter("fissureCrossingProjectileType")
  fissureCrossingProjectileParameters = config.getParameter("fissureCrossingProjectileParameters")
  lightningStrikeSpecs = config.getParameter("lightningStrikeSpecs")

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

  postLightningWaitTime = cfg.duration

  monster.setDamageBar("None")
  state = FSM:new()
  state:set(states.postInit)

  script.setUpdateDelta(3)
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
  world.spawnProjectile(fissureCrossingProjectileType, mcontroller.position(), nil, nil, nil, fissureCrossingProjectileParameters)

  util.wait(lightningStrikeSpecs.startDelay)

  for _ = 1, lightningStrikeSpecs.count do
    crackleLightning(lightningStrikeSpecs.radiusStart, lightningStrikeSpecs.radiusEnd)
    util.wait(lightningStrikeSpecs.interval)
  end

  util.wait(postLightningWaitTime)

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

function crackleLightning(radiusStart, radiusEnd)
  local randomPosStart = vec2.add(mcontroller.position(), vec2.withAngle(math.random() * 2 * math.pi, math.random() * radiusStart))
  -- Base end position on start position.
  local randomPosEnd = vec2.add(randomPosStart, vec2.withAngle(math.random() * 2 * math.pi, math.random() * radiusEnd))

  lightningController:addRandomSeed(randomPosStart, randomPosEnd)

  animator.playSound("crackle")
end

function shouldDie()
  return shouldDieVar
end

function uninit()
end