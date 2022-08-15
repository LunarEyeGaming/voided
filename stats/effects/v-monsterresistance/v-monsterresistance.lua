function init()
  world.sendEntityMessage(entity.id(), "queueRadioMessage", "v-monsterresistance")

  script.setUpdateDelta(0)
end

function update(dt)

end

function uninit()
  
end
