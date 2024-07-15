require "/scripts/v-animator.lua"
require "/scripts/util.lua"

local startColor
local endColor
local endPoisonAmount
local shimmerValues
local warningSoundRatioRange
-- local warningSoundVolumeRange
-- local warningSoundPitchRange
local warningSoundIntervalRange

local oldPoisonAmount

local postInitCalled
-- local playingWarningSound
local warningSoundTimer

function init()
  -- startColor and endColor are RBGA color tables.
  startColor = config.getParameter("startColor")
  endColor = config.getParameter("endColor")
  
  -- The poison amount to which the endColor must correspond. startColor corresponds to a poison amount of 0.
  endPoisonAmount = config.getParameter("endPoisonAmount")
  
  --[[
    A list of objects with the following entries:
      * minPoisonChangeRate: the minimum change in poison (measured in units per second) required for this shimmer rate
        to be active
      * shimmerTime: the amount of time (in seconds) it takes for one shimmer to be completed
    The script will choose the last entry in shimmerValues v such that the change in poison (in units per second) is
    greater than or equal to v.minPoisonChangeRate and sets the shimmer time in the display to v.shimmerTime.
  ]]
  shimmerValues = config.getParameter("shimmerValues")
  
  -- Controls for the sound to warn the player that their poison meter is getting full.
  -- Volume and pitch start at warningSoundVolumeRange[1] and warningSoundPitchRange[1] respectively when the poison 
  -- ratio (poisonAmount / endPoisonAmount) is at warningSoundRatioRange[1] and approach their corresponding second 
  -- entries as the ratio reaches warningSoundRatioRange[2], and they stay at said entries when the ratio passes
  -- warningSoundRatioRange[2].
  warningSoundRatioRange = config.getParameter("warningSoundRatioRange")
  -- warningSoundVolumeRange = config.getParameter("warningSoundVolumeRange")
  -- warningSoundPitchRange = config.getParameter("warningSoundPitchRange")
  warningSoundIntervalRange = config.getParameter("warningSoundIntervalRange")
  
  oldPoisonAmount = 0
  
  postInitCalled = false
  -- playingWarningSound = false
  warningSoundTimer = 0
end

function postInit()
  world.sendEntityMessage(entity.id(), "v-depthPoison-showMeter")
  
  postInitCalled = true
end

function update(dt)
  if not postInitCalled then
    postInit()
  end

  local poisonAmount = status.resource("v-depthPoison")
  
  local ratio = math.min(1.0, poisonAmount / endPoisonAmount)
  local color = vAnimator.lerpColor(ratio, startColor, endColor)
  world.sendEntityMessage(entity.id(), "v-depthPoison-setRatio", ratio)
  
  setShimmerTime(poisonAmount, dt)

  updateWarningSound(ratio, dt)
  
  setFadeColor(color)
end

-- Sets the fade directive to use the provided color. The RGB channels are used as normal, but the A channel is used to
-- set the fade amount.
function setFadeColor(color)
  local fadeColor = {color[1], color[2], color[3]}
  local fadeAmount = color[4] / 255
  effect.setParentDirectives(string.format("fade=%s=%s", vAnimator.stringOfColor(fadeColor), fadeAmount))
end

function setShimmerTime(poisonAmount, dt)
  local poisonChangeRate = (poisonAmount - oldPoisonAmount) / dt
  
  local entryToUse = nil
  
  for _, shimmerValue in ipairs(shimmerValues) do
    -- This effectively finds the last entry such that poisonChangeRate >= minPoisonChangeRate is true.
    if poisonChangeRate < shimmerValue.minPoisonChangeRate then
      break
    end

    entryToUse = shimmerValue
  end
  
  -- Use shimmer time for entry to use, or nil if no such entry is found.
  world.sendEntityMessage(entity.id(), "v-depthPoison-setShimmerTime", entryToUse and (entryToUse.shimmerTime) or nil)
  
  oldPoisonAmount = poisonAmount
end

function updateWarningSound(ratio, dt)
  if ratio > warningSoundRatioRange[1] then
    warningSoundTimer = warningSoundTimer - dt
    
    if warningSoundTimer <= 0 then
      animator.playSound("warning")

      -- Cap the ratio at warningSoundRatioRange[2]
      local cappedRatio = math.min(ratio, warningSoundRatioRange[2])
      
      -- Determine ratio to use when lerping the interval to use.
      local controlProgress = (cappedRatio - warningSoundRatioRange[1]) 
          / (warningSoundRatioRange[2] - warningSoundRatioRange[1])
      warningSoundTimer = util.lerp(controlProgress, warningSoundIntervalRange[1], warningSoundIntervalRange[2])
    end
  else
    warningSoundTimer = 0
  end
end

function onExpire()
  world.sendEntityMessage(entity.id(), "v-depthPoison-hideMeter")
end