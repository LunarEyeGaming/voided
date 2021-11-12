function init()
  object.setInteractive(true)
end

function onInteraction(args)
  local tooltip = config.getParameter("tooltip", "")
  object.say(tooltip)
end