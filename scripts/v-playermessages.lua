function init()
  message.setHandler("v-teleport", function(_, _, position)
    teleport(position)
  end)
end

function teleport(position)
  mcontroller.setPosition(position)
end