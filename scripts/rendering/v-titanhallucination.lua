require "/scripts/rect.lua"
require "/scripts/vec2.lua"
require "/scripts/v-time.lua"

local oldInit = init or function() end
local oldUpdate = update or function() end
local oldUninit = uninit or function() end

-- Parameters
local fearIncreaseRate
local fearDecreaseRate
local victoryFearDecreaseMultiplier
local maxFearDistance
local sleepStatuses

-- State variables
local fearLevel  -- Probability of a hallucination upon starting to sleep.
local wasSleeping  -- Whether or not the player had the sleeping status in the previous tick
local shouldHallucinate
local titanPositionPromise
local titanPosition
local ticker

-- Variables having to do with the hallucination itself are prefixed with "h".
local hMaxTime  -- Amount of time that must elapse before the hallucination is at max opacity and the music has stopped.
local hMaxOpacity  -- Max opacity of drawables
local hDrawablesConfig  -- Configuration for the drawables.
local hDrawablesPosition  -- Base position for the drawables

local hStopMusicTriggered  -- Whether or not the message to play silence has been sent.
local hTimer  -- Time elapsed

function init()
  oldInit()

  fearIncreaseRate = 0.3 / 120
  fearDecreaseRate = 1 / 7200
  victoryFearDecreaseMultiplier = 0.1
  maxFearDistance = 200
  sleepStatuses = {"bed1", "bed2", "bed3", "bed4", "bed5", "bed6"}

  -- fearLevel = 0
  -- fearLevel = 1.0
  fearLevel = player.getProperty("v-titanHallucination-fearLevel", 0)
  wasSleeping = false
  shouldHallucinate = false
  titanPositionPromise = nil
  titanPosition = nil

  ticker = VTicker:new()

  ticker:addInterval(1, function()
    if not v_titanHallucination_nearTitan() then
      fearLevel = math.max(0, fearLevel - fearDecreaseRate)
    end
  end)

  message.setHandler("v-titanHallucination-victory", function()
    fearLevel = fearLevel * victoryFearDecreaseMultiplier
  end)

  hMaxTime = 60 * 15
  hMaxOpacity = 128
  hDrawablesConfig = {
    {
      image = "/monsters/boss/v-titanofdarkness/lefteye.png",
      offset = {-2.875, 0.75},
      fullbright = false
    },
    {
      image = "/monsters/boss/v-titanofdarkness/righteye.png",
      offset = {4.625, 0.5},
      fullbright = false
    },
    {
      image = "/monsters/boss/v-titanofdarkness/body.png",
      offset = {0, 0},
      fullbright = false
    }
  }
  hDrawablesPosition = {0, 15}

  hStopMusicTriggered = false
  hTimer = 0
end

function update(dt)
  localAnimator.clearDrawables()

  oldUpdate(dt)

  -- world.debugText("fearLevel: %s, shouldHallucinate: %s", fearLevel, shouldHallucinate, vec2.add(entity.position(), {0, -5}), "green")

  ticker:update(dt)

  if v_titanHallucination_nearTitan() then
    fearLevel = fearLevel + fearIncreaseRate * dt
  end

  local isSleeping = v_titanHallucination_hasSleepStatus()

  -- If the player has started sleeping, then with a chance of fearLevel...
  if isSleeping and not wasSleeping and math.random() < fearLevel then
    shouldHallucinate = true
    -- sb.logInfo("Test")
  end

  if not isSleeping and shouldHallucinate then
    world.sendEntityMessage(player.id(), "stopAltMusic", 0)
    hStopMusicTriggered = false
    hTimer = 0

    shouldHallucinate = false
  end

  if shouldHallucinate then
    v_titanHallucination_hallucinate(dt)
  end

  v_titanHallucination_updateTitanPosition()

  wasSleeping = isSleeping
end

---Asynchronously updates the position of the Titan as frequently as the server allows.
---@postconditions: upon titanPositionPromise finishing, titanPosition is modified and titanPositionPromise is unset
function v_titanHallucination_updateTitanPosition()
  -- If no promise is pending...
  if not titanPositionPromise then
    -- Request the position of the Titan.
    titanPositionPromise = world.findUniqueEntity("v-titanofdarkness")
  end

  -- If the promise has finished...
  if titanPositionPromise:finished() then
    titanPosition = titanPositionPromise:result()

    -- Unset promise
    titanPositionPromise = nil
  end
end

function v_titanHallucination_nearTitan()
  return titanPosition and rect.contains(world.clientWindow(), titanPosition)
  -- return world.magnitude(entity.position(), titanPosition) < maxFearDistance
end

function v_titanHallucination_hasSleepStatus()
  -- Find the first status effect that the player has.
  for _, effectName in ipairs(sleepStatuses) do
    if status.uniqueStatusEffectActive(effectName) then
      return true
    end
  end

  return false
end

function v_titanHallucination_hallucinate(dt)
  if not hStopMusicTriggered then
    world.sendEntityMessage(player.id(), "playAltMusic", {"/sfx/npc/boss/v_titanofdarkness_ambience.ogg"}, hMaxTime)
    hStopMusicTriggered = true
  end

  local ratio = math.min(1.0, hTimer / hMaxTime)

  for _, drawable in ipairs(hDrawablesConfig) do
    localAnimator.addDrawable({
      image = drawable.image,
      position = vec2.add(hDrawablesPosition, drawable.offset),
      fullbright = drawable.fullbright,
      -- Lerp opacity between 0 and hMaxOpacity. Cap between 0 and 255.
      color = {255, 255, 255, math.floor(math.max(math.min(hMaxOpacity * ratio, 255), 0))}
    })
  end
  hTimer = hTimer + dt
end

function uninit()
  oldUninit()

  player.setProperty("v-titanHallucination-fearLevel", fearLevel)
end