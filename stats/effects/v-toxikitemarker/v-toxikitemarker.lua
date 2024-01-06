require "/scripts/status.lua"

local listener
local poisonEffect

function init()
  poisonEffect = config.getParameter("poisonEffect")

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
  listener:update()
end

function inflictPoison()
  status.addEphemeralEffect(poisonEffect)
end