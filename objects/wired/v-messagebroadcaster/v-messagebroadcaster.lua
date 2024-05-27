require "/scripts/vec2.lua"

local messageType
local messageArgs
local messageSourceOffset
local messageRadius
local messageQuerySettings

function init()
  messageType = config.getParameter("messageType")  -- The type of message to broadcast
  messageArgs = config.getParameter("messageArgs", jarray())  -- The arguments to supply to the message
  messageSourceOffset = config.getParameter("messageSourceOffset")  -- The center of the message broadcast region
  messageRadius = config.getParameter("messageRadius")  -- The radius of the broadcast
  messageQuerySettings = config.getParameter("messageQuerySettings")  -- The settings of the initial query of recipients
end

function onNodeConnectionChange(args)
  attemptBroadcast()
end

function onInputNodeChange(args)
  attemptBroadcast()
end

function attemptBroadcast()
  -- If no input node is connected or input is on...
  if (not object.isInputNodeConnected(0)) or object.getInputNodeLevel(0) then
    -- Query the entities to send the message to.
    local queried = world.entityQuery(vec2.add(object.position(), messageSourceOffset), messageRadius, messageQuerySettings)
    
    -- For each queried entity...
    for _, entityId in ipairs(queried) do
      -- Send the message to that entity.
      world.sendEntityMessage(entityId, messageType, table.unpack(messageArgs))
    end
  end
end