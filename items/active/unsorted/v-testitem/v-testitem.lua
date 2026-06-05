require "/scripts/util.lua"
require "/scripts/vec2.lua"

function init()
end

function update(dt, fireMode)
  activeItem.setScriptedAnimationParameter("riftPolyCenter", activeItem.ownerAimPosition())
end