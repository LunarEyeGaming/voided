function init()
  message.setHandler("v-teleport", function(_, _, position)
    mcontroller.setPosition(position)
  end)
end