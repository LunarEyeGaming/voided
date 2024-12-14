local immunityDuration  -- The amount of time to wait before revoking immunity
local immunityGroup
local timer

function init()
  immunityDuration = config.getParameter("immunityDuration")
  -- Add temporary charged ground immunity to give the player time to react.
  immunityGroup = effect.addStatModifierGroup({{stat = config.getParameter("immunityStatName"), amount = 1}})

  timer = immunityDuration  -- Set timer

  -- Show warning.
  world.sendEntityMessage(entity.id(), "queueRadioMessage", "v-chargedgroundwarning")
end

function update(dt)
  -- If the immunity time period is not over yet...
  if timer then
    timer = timer - dt

    -- If the immunity time period is now over...
    if timer <= 0 then
      effect.removeStatModifierGroup(immunityGroup)  -- Remove immunity
      timer = nil  -- Mark immunity timer period as over.
      immunityGroup = nil  -- Clear immunity group from memory
    end
  end
end

function uninit()
  -- If the immunity was not already removed...
  if immunityGroup then
    effect.removeStatModifierGroup(immunityGroup)  -- Remove immunity when uninitializing
  end
end