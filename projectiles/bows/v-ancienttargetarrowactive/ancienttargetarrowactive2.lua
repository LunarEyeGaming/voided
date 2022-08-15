require "/scripts/vec2.lua"
require "/scripts/util.lua"

local oldInit = init or function() end
local oldUpdate = update or function() end

local shouldCollide

function init()
  oldInit()
  shouldCollide = false
end

function update(dt)
  oldUpdate(dt)
  
  if not shouldCollide then
    if not world.polyCollision(mcontroller.collisionPoly(), mcontroller.position()) then
      shouldCollide = true
    end
    mcontroller.applyParameters({collisionEnabled = false})
  else
    mcontroller.applyParameters({collisionEnabled = true})
  end
end
