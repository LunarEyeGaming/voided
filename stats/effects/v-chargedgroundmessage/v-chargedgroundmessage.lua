function init()
  world.sendEntityMessage(entity.id(), "queueRadioMessage", "v-chargedgroundwarning")
  script.setUpdateDelta(0)
end