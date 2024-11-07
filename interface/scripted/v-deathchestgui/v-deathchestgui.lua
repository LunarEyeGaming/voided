local containerId
local postInitCalled

function init()
  containerId = pane.containerEntityId()
  postInitCalled = false
end

function postInit()
  world.sendEntityMessage(containerId, "open")
end

function update(dt)
  if not postInitCalled then
    postInit()
    postInitCalled = true
  end
end

function dismissed()
  world.sendEntityMessage(containerId, "close")  -- Trigger closing animation
end