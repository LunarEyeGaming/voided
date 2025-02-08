local useActionOnMerge
local actionOnMerge
local actionOnNonMerge

function init()
  message.setHandler("v-handleMerge", function(_, _, senderSourceEntity)
    -- Ensure that the sender has the same source entity as the current projectile.
    if senderSourceEntity == projectile.sourceEntity() then
      useActionOnMerge = true
      projectile.die()
    end
  end)
  useActionOnMerge = false
  actionOnMerge = config.getParameter("actionOnMerge")
  actionOnNonMerge = config.getParameter("actionOnNonMerge")
  mergeHandlerType = config.getParameter("mergeHandlerType")
end

function update(dt)

end

function v_isMergerType(type_)
  return type_ == mergeHandlerType
end

function destroy()
  if useActionOnMerge then
    projectile.processAction(actionOnMerge)
  else
    projectile.processAction(actionOnNonMerge)
  end
end