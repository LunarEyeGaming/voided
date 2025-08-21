require "/scripts/vec2.lua"
require "/objects/wired/switch/switch.lua"

local oldInit = init or function() end

function init()
  oldInit()

  -- Suppress object.setInteractive(true) call
  object.setInteractive(false)

  message.setHandler("v-wirelessswitch-trigger", v_wirelessSwitch_onTrigger)

  message.setHandler("v-monsterwavespawner-reset", v_wirelessSwitch_onReset)
end

function v_wirelessSwitch_onTrigger()
  if storage.state == false then
    output(true)
  end
end

function v_wirelessSwitch_onReset()
  if storage.state == true then
    output(false)
  end
end