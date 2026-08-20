require "/scripts/vec2.lua"
require "/scripts/interp.lua"
require "/scripts/util.lua"
require "/scripts/v-animator.lua"

local followPlayer
local fissureCrossingProjectileType
local fissureCrossingProjectileParameters
local lightningStrikeSpecs
local postLightningWaitTime
local starCutscene

local shouldDieVar
local lightningController
local state

function init()
  followPlayer = config.getParameter("masterId")
  fissureCrossingProjectileType = config.getParameter("fissureCrossingProjectileType")
  fissureCrossingProjectileParameters = config.getParameter("fissureCrossingProjectileParameters")
  lightningStrikeSpecs = config.getParameter("lightningStrikeSpecs")
  starCutscene = config.getParameter("starCutscene", {})
  table.sort(starCutscene, function(a, b) return a.timecode < b.timecode end)

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

  if followPlayer then
    local pos = world.entityPosition(followPlayer)
    if pos then
      mcontroller.setPosition(pos)
    end
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
  local cutscene = copy(starCutscene)
  local timer = 0
  local timeEnd = starCutscene[#starCutscene].timecode
  while timer <= timeEnd do
    timer = timer + script.updateDt()

    -- Invoke each effect whose timecode has passed, then remove it so it isn't invoked again.
    for i = #cutscene, 1, -1 do
      local specialEffect = cutscene[i]
      if timer >= specialEffect.timecode then
        local players = world.players()
        for _, playerId in ipairs(players) do
          if world.entityExists(playerId) then
            world.sendEntityMessage(playerId, "v-invokeSpecialEffect", specialEffect.kind, specialEffect.arguments, false, mcontroller.position())
          end
        end
        table.remove(cutscene, i)
        -- sb.logInfo(sb.printJson(cutscene, 2))
      end
    end

    coroutine.yield()
  end
  -- world.spawnProjectile(fissureCrossingProjectileType, mcontroller.position(), nil, nil, nil, fissureCrossingProjectileParameters)

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
  local players = world.players()
  for _, playerId in ipairs(players) do
    if world.entityExists(playerId) then
      local randomPos = vec2.add(world.entityPosition(playerId), vec2.withAngle(math.random() * 2 * math.pi, math.random() * radiusStart))
      world.spawnMonster("v-riftzonelightning", randomPos)
    end
  end
end

function shouldDie()
  return shouldDieVar
end

function uninit()
end