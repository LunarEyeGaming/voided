require "/scripts/util.lua"
require "/scripts/v-animator.lua"

local preFreezeMovementModifiers
local freezeMovementModifiers
local freezeDuration
local freezeDamage
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
  if world.entityType(entity.id()) == "player" then
    script.setUpdateDelta(0)
    return
  end

  preFreezeMovementModifiers = {
    speedModifier = 0.9,
    airJumpModifier = 0.9
  }
  freezeMovementModifiers = {
    movementSuppressed = true,
    jumpingSuppressed = true
  }
  freezeDuration = 2.0
  freezeDamage = 150
  warmthIncreaseRate = 30
  warmthIncreaseBlockTime = 3.0
  warmthIncreaseBlock = 0
  maxWarmth = 60
  warmth = maxWarmth

  startFadeColor = vAnimator.stringToColor(config.getParameter("startFadeColor"))
  startFadeAmount = config.getParameter("startFadeAmount")
  endFadeColor = vAnimator.stringToColor(config.getParameter("endFadeColor"))
  endFadeAmount = config.getParameter("endFadeAmount")

  state = "inactive"
  freezeTimer = 0

  message.setHandler("v-simulatedwarmth-consume", function(_, _, amount)
    warmth = math.max(0, warmth - amount)
    onWarmthConsumed(amount)
  end)
end

function onWarmthConsumed(amount)
  if amount > 0 then
    warmthIncreaseBlock = warmthIncreaseBlockTime
  end
end

function update(dt)
  local warmthPercentage = warmth / maxWarmth
  world.debugText("%s", warmthPercentage, mcontroller.position(), "green")

  -- Update display of warmth
  local fadeColor = vAnimator.lerpColorRGB(1 - warmthPercentage, startFadeColor, endFadeColor)
  local fadeAmount = util.lerp(1 - warmthPercentage, startFadeAmount, endFadeAmount)
  effect.setParentDirectives(string.format("?fade=%s=%s", vAnimator.colorToString(fadeColor), fadeAmount))

  -- Update state
  freezeTimer = freezeTimer - dt
  if state == "inactive" then
    if warmthPercentage < 1.0 then
      state = "preFreeze"
    end
  elseif state == "preFreeze" then
    mcontroller.controlModifiers(preFreezeMovementModifiers)
    if warmthPercentage <= 0 then
      onFreeze()

      freezeTimer = freezeDuration
      state = "freeze"
    elseif warmthPercentage == 1.0 then
      state = "inactive"
    end
  elseif state == "freeze" then
    mcontroller.controlModifiers(freezeMovementModifiers)

    if freezeTimer <= 0 then
      onFreezeDamage()
      state = "inactive"
    end
  else
    sb.logError("v-freezing: Invalid state")
  end

  -- Handle increasing of warmth resource manually.
  if warmthIncreaseBlock <= 0 then
    warmth = math.min(maxWarmth, warmth + warmthIncreaseRate * dt)
  end

  warmthIncreaseBlock = math.max(0, warmthIncreaseBlock - dt)
end

function onFreezeDamage()
  status.applySelfDamageRequest({
    damageType = "IgnoresDef",
    damage = freezeDamage,
    damageSourceKind = "ice",
    sourceEntityId = entity.id()
  })

  warmth = maxWarmth  -- Reset warmth.
end

function onFreeze()
  status.addEphemeralEffect("v-frozen")
end