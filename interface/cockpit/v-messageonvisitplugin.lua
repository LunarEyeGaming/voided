--[[
  A simple hook script that sends a series of radio messages to all nearby players when the ship is in an Outsider Star
  system.
]]

local messageSendRadius = 250
local sentMessage

local oldInit = init or function() end
local oldUpdate = update or function() end

function init()
  oldInit()

  sentMessage = false
end

function update(dt)
  oldUpdate(dt)
  -- If a message has not been sent yet and the player is in an extradimensional star system...
  if not sentMessage and v_isInExtradimensionalSystem() then
    local queried = world.entityQuery(world.entityPosition(player.id()), messageSendRadius)

    local messages = config.getParameter("v-extradimensionalStarMessages")
    -- Send messages to all nearby players
    for _, entityId in ipairs(queried) do
      for _, msg in ipairs(messages) do
        world.sendEntityMessage(entityId, "queueRadioMessage", msg)
      end
    end
    -- Set sentMessage flag
    sentMessage = true
  end
end

---Returns `true` if the player is (for certain) in an Outsider Star system and `false` otherwise.
---@return boolean
function v_isInExtradimensionalSystem()
  local currentSystemParams = celestial.planetParameters(celestial.currentSystem())
  return currentSystemParams and currentSystemParams.typeName == "v-extradimensional"
end