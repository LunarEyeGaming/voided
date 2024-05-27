require "/scripts/vec2.lua"
require "/objects/wired/momentaryswitch/momentaryswitch.lua"

local oldInit = init or function() end

function init()
  oldInit()
  
  -- Suppress object.setInteractive(true) call
  object.setInteractive(false)
  
  message.setHandler("v-wirelessmomentaryswitch-trigger", v_wirelessMomentarySwitch_onTrigger)
end

function v_wirelessMomentarySwitch_onTrigger()
  if storage.state == false then
    output(true)
  end

  storage.timer = self.interval
end