require "/scripts/util.lua"

--[[
  A plugin that gives diminishing returns for damage requests given in a short interval of time. This is done through
  a damage multiplier that compounds itself for each damage request, starting at 1.0 and being multiplied by
  `damageMultiplierPerRequest` each time. This multiplier resets itself if more than `damageMultiplierResetDelay`
  seconds have passed since the last damage request. This reset is gradual and reverses the effect of one hit every
  `damageMultiplierResetInterval` seconds. In addition, the compounding can occur only with hits that exceed the
  threshold `damageMultiplierThreshold` in damage.
]]

local oldInit = init or function() end
local oldUpdate = update or function() end
local oldApplyDamageRequest = applyDamageRequest or function() end

local damageMultiplier
local damageMultiplierPerRequest
local invDamageMultiplierPerRequest
local damageMultiplierResetDelay
local damageMultiplierResetInterval
local damageMultiplierThreshold
local resetDelayTimer

function init()
  oldInit()

  damageMultiplier = 1.0
  damageMultiplierPerRequest = status.statusProperty("damageMultiplierPerRequest", 0.25)
  invDamageMultiplierPerRequest = 1 / damageMultiplierPerRequest  -- inverse of damageMultiplierPerRequest
  damageMultiplierResetDelay = status.statusProperty("damageMultiplierResetDelay", 0.05)
  damageMultiplierResetInterval = status.statusProperty("damageMultiplierResetInterval", 0.05)
  damageMultiplierThreshold = status.statusProperty("damageMultiplierThreshold", 100)
  resetDelayTimer = 0
  resetIntervalTimer = 0
end

-- TODO: Figure out how to make the damageMultiplierThreshold smooth.
function applyDamageRequest(damageRequest)
  local newDamageRequest = copy(damageRequest)

  newDamageRequest.damage = newDamageRequest.damage * damageMultiplier

  -- Compound the damage multiplier if the damage exceeds the threshold.
  if damageRequest.damage > damageMultiplierThreshold then
    damageMultiplier = damageMultiplier * damageMultiplierPerRequest
  else
    -- Still compound the damage multiplier, but do it at a lower rate depending on how much damage is being dealt.
    damageMultiplier = damageMultiplier * util.lerp(damageRequest.damage / damageMultiplierThreshold, 1.0, damageMultiplierPerRequest)
  end

  resetDelayTimer = damageMultiplierResetDelay
  resetIntervalTimer = damageMultiplierResetInterval

  return oldApplyDamageRequest(newDamageRequest)
end

function update(dt)
  oldUpdate(dt)

  resetDelayTimer = resetDelayTimer - dt

  -- On each tick that the reset delay timer is zero or negative...
  if resetDelayTimer <= 0 then
    -- Decrease the interval timer
    resetIntervalTimer = resetIntervalTimer - dt

    -- Once it reaches zero...
    if resetIntervalTimer <= 0 then
      -- Multiply the damage multiplier back up and reset the interval timer.
      damageMultiplier = math.min(1.0, damageMultiplier * invDamageMultiplierPerRequest)
      resetIntervalTimer = damageMultiplierResetInterval
    end
  end
end