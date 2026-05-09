local oldInit = init or function() end
local oldUpdate = update or function() end
local oldNotifyResourceConsumed = notifyResourceConsumed or function() end

local preFreezeMovementModifiers
local freezeMovementModifiers
local freezeDuration
local freezeDamage
local warmthIncreaseRate

local freezeTimer
local state

function init()
  oldInit()

  preFreezeMovementModifiers = {
    speedModifier = 0.9,
    airJumpModifier = 0.9
  }
  freezeMovementModifiers = {
    movementSuppressed = true,
    jumpingSuppressed = true
  }
  freezeDuration = 2.0
  freezeDamage = 60
  warmthIncreaseRate = 50

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

  -- Freezing stuff.
  local warmthPercentage = status.resourcePercentage("v-warmth")
  world.sendEntityMessage(entity.id(), "v-drawableMeter-setFillRatio", "v-freezing", 1 - warmthPercentage)
  world.debugText("state: %s, timer: %s, warmthPercentage: %s", state, freezeTimer, warmthPercentage, mcontroller.position(), "green")
  freezeTimer = freezeTimer - dt
  if state == "inactive" then
    if warmthPercentage < 1.0 then
      world.sendEntityMessage(entity.id(), "v-drawableMeter-show", "v-freezing")

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

      world.sendEntityMessage(entity.id(), "v-drawableMeter-hide", "v-freezing")
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
  if not status.resourcePositive("v-warmthIncreaseBlock") then
    status.modifyResource("v-warmth", warmthIncreaseRate * dt)
  end
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