local useActionOnMerge
local actionOnMerge
local actionOnNonMerge

function init()
  message.setHandler("v-handleMerge", function()
    useActionOnMerge = true
    projectile.die()
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