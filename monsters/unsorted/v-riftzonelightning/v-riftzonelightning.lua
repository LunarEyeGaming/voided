require "/scripts/vec2.lua"
require "/scripts/util.lua"
require "/scripts/rect.lua"

require "/scripts/v-animator.lua"

local lightningController

local thread

local shouldDieVar

function init()
  shouldDieVar = false

  local cfg = config.getParameter("lightningConfig", {})

  remainingTime = cfg.duration

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

  thread = coroutine.create(main)
  local status, result = coroutine.resume(thread)
  if not status then
    error(result)
  end
end

function update(dt)
  lightningController:update(dt)

  if coroutine.status(thread) ~= "dead" then
    local status, result = coroutine.resume(thread)
    if not status then
      error(result)
    end
  end
end

function shouldDie()
  return shouldDieVar
end

function uninit()
end

function main()
  for _ = 1, 2 do
    coroutine.yield()
  end

  local offsetRegion = config.getParameter("endpointOffsetRegion", {-1, -1, 1, 1})
  local randomPosStart = vec2.add(mcontroller.position(), rect.randomPoint(offsetRegion))
  local randomPosEnd = vec2.add(mcontroller.position(), rect.randomPoint(offsetRegion))

  lightningController:addRandomSeed(randomPosStart, randomPosEnd)

  animator.playSound("crackle")

  util.wait(remainingTime)

  shouldDieVar = true

  -- The script should stop running within the next tick or two. This just ensures the coroutine doesn't die prematurely
  -- and cause an error.
  while true do
    coroutine.yield()
  end
end