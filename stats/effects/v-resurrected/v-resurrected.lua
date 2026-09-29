require "/scripts/util.lua"
require "/scripts/v-animator.lua"

local preFreezeMovementModifiers
local freezeMovementModifiers
local freezeDuration
local freezeDamage

-- maxWarmth and warmthIncreaseRate scale with knockbackThreshold if defined.
local maxWarmthFactor
local warmthIncreaseRateFactor

local warmthIncreaseRate
local warmthIncreaseBlockTime
local warmthIncreaseBlock
local maxWarmth
local warmth

local startFadeColor
local startFadeAmount
local endFadeColor
local endFadeAmount

local freezeTimer
local state

function init()
  effect.setParentDirectives(config.getParameter("directives"))
end