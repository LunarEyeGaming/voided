require "/scripts/poly.lua"

local selfDamagePoly

local oldInit = init or function() end
local oldUpdate = update or function() end

function init()
  oldInit()

  selfDamagePoly = config.getParameter("selfDamagePoly")
end

function update(dt)
  oldUpdate(dt)

  if selfDamagePoly then
    world.debugPoly(poly.translate(selfDamagePoly, mcontroller.position()), "magenta")
  end
end