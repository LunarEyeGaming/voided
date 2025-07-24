function init()
end

function update(dt)
end

function dismissed()
  if widget.getChecked("btnNeverShowAgain") then
    world.sendEntityMessage(player.id(), "v-neverShowAgain-" .. config.getParameter("popupId"))
  end
end

function btnNeverShowAgain()

end