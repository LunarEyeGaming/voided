--[[
  A simple script that tells the container to open immediately after this pane is opened and to close when this pane is
  closed. The container must be scripted to handle the messages "open" and "close" to open and close the container
  respectively. One would use this script when they want to use more complex animations for the container (such as
  having multiple frames for when the container is opened or closed) by making a copy of the GUI configuration to
  display, having it use this script, and making the container's `uiConfig` parameter point to the GUI config that was
  modified.

  In this particular case, it is used by v-deathchest.
]]

local containerId

function init()
  -- Container ID needs to be cached because the value of `pane.containerEntityId()` is unreliable within the
  -- `dismissed()` function.
  containerId = pane.containerEntityId()

  -- Tell the container to open (sending messages in the init function of a pane does not cause any problems)
  world.sendEntityMessage(containerId, "open")
end

-- Called when the pane is closed.
function dismissed()
  -- Tell the container to close
  world.sendEntityMessage(containerId, "close")  -- Trigger closing animation
end