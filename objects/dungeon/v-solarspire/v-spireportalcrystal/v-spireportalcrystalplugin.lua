function onOutputChange(state)
  if state then
    local radioMessagesOnRepair = config.getParameter("radioMessagesOnRepair", {})
    local radioMessageRange = config.getParameter("radioMessageRange", 100)

    local queried = world.entityQuery(object.position(), radioMessageRange, {includedTypes = {"player"}})
    for _, playerId in ipairs(queried) do
      for _, msg in ipairs(radioMessagesOnRepair) do
        world.sendEntityMessage(playerId, "queueRadioMessage", msg)
      end
    end

    world.sendEntityMessage("v-spireportal", "v-crystalRepaired")
  end
end