

function init()
  if not storage.state then
    storage.state = {}
  end
  message.setHandler("v-dungeonquestmanager-getStage", function()
    return storage.state.stage
  end)

  message.setHandler("v-dungeonquestmanager-setStage", function(_, _, state)
    storage.state.stage = state
  end)

  message.setHandler("v-dungeonquestmanager-")
end