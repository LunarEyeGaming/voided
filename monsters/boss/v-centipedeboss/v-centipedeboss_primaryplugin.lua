require "/scripts/util.lua"

--[[
  A plugin that gives diminishing returns for damage requests given in a short interval of time. This is done through
  a damage multiplier that compounds itself for each damage request, starting at 1.0 and being multiplied by
  `damageMultiplierPerRequest` each time. This multiplier resets itself if more than `damageMultiplierResetTime` seconds
  have passed since the last damage request.
]]

local oldInit = init or function() end
local oldUpdate = update or function() end
local oldApplyDamageRequest = applyDamageRequest or function() end

local damageMultiplier
local damageMultiplierPerRequest
local damageMultiplierResetTime
local resetTimer

function init()
  oldInit()

  damageMultiplier = 1.0
  damageMultiplierPerRequest = status.statusProperty("damageMultiplierPerRequest", 0.1)
  damageMultiplierResetTime = status.statusProperty("damageMultiplierResetTime", 0.05)
  resetTimer = 0
end

function applyDamageRequest(damageRequest)
  local newDamageRequest = copy(damageRequest)

  newDamageRequest.damage = newDamageRequest.damage * damageMultiplier
  damageMultiplier = damageMultiplier * damageMultiplierPerRequest

  resetTimer = damageMultiplierResetTime

  return oldApplyDamageRequest(newDamageRequest)
end

function update(dt)
  oldUpdate(dt)

  resetTimer = resetTimer - dt

  if resetTimer <= 0 then
    damageMultiplier = 1.0
  end
end