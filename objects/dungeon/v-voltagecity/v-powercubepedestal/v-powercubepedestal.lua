local oldOnInteraction = onInteraction or function() end

function onInteraction(args)
  oldOnInteraction(args)
  
  -- Send message to entity with given ID that this power cube has been collected.
  world.sendEntityMessage(config.getParameter("minibossUniqueId"), "notify", {
    type = "v-powerCubeCollected"
  })
end