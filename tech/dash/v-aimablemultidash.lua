require "/tech/dash/v-aimabledash.lua"

local oldInit = init or function() end
local oldUpdate = update or function() end
local oldEndDash = endDash or function() end

-- Parameters
local maxStamina
local staminaRegenRate
local staminaThresholdPitches

-- State variables
local nextRechargeThreshold
local stamina
local prevStamina

function init()
  oldInit()

  maxStamina = config.getParameter("maxDashCount")
  staminaRegenRate = config.getParameter("dashRegenRate")
  staminaThresholdPitches = config.getParameter("dashThresholdPitches")

  nextRechargeThreshold = maxStamina + 1
  stamina = maxStamina
  prevStamina = maxStamina
end

function update(args)
  stamina = math.min(maxStamina, stamina + staminaRegenRate * args.dt)

  oldUpdate(args)

  world.debugText("stamina: %s\nprevStamina: %s\nnextRechargeThreshold: %s", stamina, prevStamina, nextRechargeThreshold, vec2.add(mcontroller.position(), {0, -5}), "green")

  prevStamina = stamina
end

function canDash()
  return stamina >= 1
end

function endDash(direction)
  oldEndDash(direction)

  stamina = stamina - 1
  nextRechargeThreshold = nextRechargeThreshold - 1
end

function updateRecharge(dt)
  if prevStamina < nextRechargeThreshold and stamina >= nextRechargeThreshold then
    animator.setGlobalTag("stamina", math.floor(stamina))
    animator.setAnimationState("recharge", "on")
    animator.setSoundPitch("recharge", staminaThresholdPitches[nextRechargeThreshold])
    triggerRecharge()
    nextRechargeThreshold = nextRechargeThreshold + 1
  end
end