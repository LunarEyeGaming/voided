require "/scripts/status.lua"

local listener
local poisonEffect  -- Type of poison to inflict by default.
local strongPoisonEffect  -- Type of poison to inflict when a weapon already inflicts poisonEffect
local poisonEffectDuration  -- Fractional duration of poison effect in current tick. nil if no poison effect is active.
-- Fractional duration of poison effect in previous tick. Used to detect poison inflicted by the weapon itself.
local prevPoisonEffectDuration
local hasInflictedPoison  -- Whether or not poison has been inflicted on the previous tick.

function init()
  poisonEffect = config.getParameter("poisonEffect")
  strongPoisonEffect = config.getParameter("strongPoisonEffect")

  listener = damageListener("damageTaken", function(notifications)
    -- Inflict poison for the first damage source from the source entity that deals actual damage.
    for _, notification in ipairs(notifications) do
      if notification.sourceEntityId == effect.sourceEntity() and notification.healthLost > 0 then
        inflictPoison()
        return
      end
    end
  end)
end

function update(dt)
  updatePoisonEffectDuration()

  listener:update()

  hasInflictedPoison = false
end

function inflictPoison()
  -- If the fractional duration of the poison is no longer nil, or it has increased and poison has not been inflicted by this effect on the
  -- previous tick, then something else has inflicted it, so...
  if ((not prevPoisonEffectDuration and poisonEffectDuration)
  or (prevPoisonEffectDuration and poisonEffectDuration and poisonEffectDuration > prevPoisonEffectDuration))
  and not hasInflictedPoison then
    status.addEphemeralEffect(strongPoisonEffect)
    status.removeEphemeralEffect(poisonEffect)
  else
    status.addEphemeralEffect(poisonEffect)
  end

  hasInflictedPoison = true
end

function debugEffects()
  local effects = status.activeUniqueStatusEffectSummary()

  local display = ""

  for _, effectTable in ipairs(effects) do
    display = display .. string.format("{name: %s, duration: %2.2f}, ", effectTable[1], effectTable[2])
  end
  world.debugText("Status effects: %s", display, mcontroller.position(), "green")
end

function updatePoisonEffectDuration()
  prevPoisonEffectDuration = poisonEffectDuration

  local effects = status.activeUniqueStatusEffectSummary()
  local hasPoisonEffect = false

  -- For each effect...
  for _, effectTable in ipairs(effects) do
    -- If its name equals poisonEffect...
    if effectTable[1] == poisonEffect then
      hasPoisonEffect = true  -- Mark as having the poison effect
      poisonEffectDuration = effectTable[2]  -- Update duration
    end
  end

  if not hasPoisonEffect then
    poisonEffectDuration = nil  -- Set to nil to signal that no poison effect is active.
  end
end