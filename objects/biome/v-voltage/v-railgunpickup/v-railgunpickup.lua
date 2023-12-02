require "/scripts/util.lua"
require "/scripts/vec2.lua"

function init()
  object.setInteractive(true)
end

function onInteraction(args)
  object.smash()
end