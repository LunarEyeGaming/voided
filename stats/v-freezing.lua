local oldInit = init or function() end
local oldUpdate = update or function() end
local oldNotifyResourceConsumed = notifyResourceConsumed or function() end

local preFreezeMovementModifiers
local freezeMovementModifiers
local freezeDuration
local freezeDamage
local shimmerValues
local shimmerHideTime
local oldAmount

local freezeTimer
local shimmerHideTimer
local state

function init()
  oldInit()

  local cfg = root.assetJson("/stats/v-freezing.config")

  preFreezeMovementModifiers = cfg.preFreezeMovementModifiers or {}
  freezeMovementModifiers = cfg.freezeMovementModifiers or {}
  freezeDuration = cfg.freezeDuration
  freezeDamage = cfg.freezeDamage
  shimmerValues = cfg.shimmerValues
  shimmerHideTime = cfg.shimmerHideTime
  oldAmount = status.stat("v-warmth")

  shimmerHideTimer = shimmerHideTime

  state = "inactive"
  freezeTimer = 0
end

function notifyResourceConsumed(resourceName, amount)
  oldNotifyResourceConsumed(resourceName, amount)

  if resourceName == "v-warmth" and amount > 0 then
    status.setResourcePercentage("v-warmthIncreaseBlock", 1.0)
  end
end

function update(dt)
  oldUpdate(dt)

  if status.resourcePercentage("v-warmth") < 1.0 then
    world.sendEntityMessage(entity.id(), "v-drawableMeter-show", "v-freezing")
  else
    world.sendEntityMessage(entity.id(), "v-drawableMeter-hide", "v-freezing")
  end

  local warmthPercentage = status.resourcePercentage("v-warmth")
  world.sendEntityMessage(entity.id(), "v-drawableMeter-setFillRatio", "v-freezing", 1 - warmthPercentage)
  freezeTimer = freezeTimer - dt
  if state == "inactive" then
    if warmthPercentage < 1.0 then
      state = "preFreeze"
    end
  elseif state == "preFreeze" then
    mcontroller.controlModifiers(preFreezeMovementModifiers)
    if warmthPercentage <= 0 then
      onFreeze()

      world.sendEntityMessage(entity.id(), "v-drawableMeter-invoke", "v-freezing", "setFrozen", true)

      freezeTimer = freezeDuration
      state = "freeze"
    elseif warmthPercentage == 1.0 then
      if status.statPositive("v-warm") then
        state = "warm"
      else
        state = "inactive"
      end
    end
  elseif state == "freeze" then
    mcontroller.controlModifiers(freezeMovementModifiers)

    if freezeTimer <= 0 then
      onFreezeDamage()
      world.sendEntityMessage(entity.id(), "v-drawableMeter-invoke", "v-freezing", "setFrozen", false)
      state = "inactive"
    end
  elseif state == "warm" then
    if not status.statPositive("v-warm") then
      state = "inactive"
    end
  else
    sb.logError("v-freezing: Invalid state")
  end

  -- Handle increasing of warmth resource manually.
  if not status.resourcePositive("v-warmthIncreaseBlock") then
    status.modifyResource("v-warmth", status.stat("v-warmthIncreaseRate") * dt)
  end

  -- Display warmth
  world.sendEntityMessage(entity.id(), "v-drawableMeter-invoke", "v-freezing", "setWarmth", status.statPositive("v-warm"))

  -- Shimmering
  setShimmerTime(status.resource("v-warmth"), dt)
end

function setShimmerTime(amount, dt)
  local changeRate = (oldAmount - amount) / dt

  local entryToUse = nil

  for _, shimmerValue in ipairs(shimmerValues) do
    -- This effectively finds the last entry such that changeRate >= minChangeRate is true.
    if changeRate < shimmerValue.minChangeRate then
      break
    end

    entryToUse = shimmerValue
  end

  -- Use entryToUse.shimmerTime if available. Otherwise, hide after a delay.
  if entryToUse then
    world.sendEntityMessage(entity.id(), "v-drawableMeter-invoke", "v-freezing", "setShimmerTime", entryToUse.shimmerTime)
    shimmerHideTimer = shimmerHideTime
  elseif shimmerHideTimer then
    shimmerHideTimer = shimmerHideTimer - dt

    if shimmerHideTimer <= 0 then
      world.sendEntityMessage(entity.id(), "v-drawableMeter-invoke", "v-freezing", "setShimmerTime", nil)
    end
  end

  oldAmount = amount
end

function onFreezeDamage()
  status.applySelfDamageRequest({
    damageType = "IgnoresDef",
    damage = freezeDamage,
    damageSourceKind = "ice",
    sourceEntityId = entity.id()
  })

  world.sendEntityMessage(entity.id(), "v-drawableMeter-hide", "v-freezing")
  status.setResourcePercentage("v-warmth", 1.0)  -- Reset warmth.
end

function onFreeze()
  status.addEphemeralEffect("v-frozen")
end