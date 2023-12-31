function init()
end

function update(dt)
end

function dismissed()
  if widget.getChecked("btnNeverShowAgain") then
    world.sendEntityMessage(pane.sourceEntity(), "v-neverShowAgain")
  end
end

function btnNeverShowAgain()
  
end