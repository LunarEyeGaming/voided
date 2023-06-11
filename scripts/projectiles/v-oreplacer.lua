require "/scripts/vec2.lua"

--[[
  This script places ores in a given radius around the projectile when it dies and does so with a given probability. The
  script can be used in conjunction with other scripts.
]]

local oldInit = init or function() end
local oldDestroy = destroy or function() end

local radius
local oreType
local oreChance

function init()
  oldInit()
  
  radius = config.getParameter("radius")  -- The radius of the circle of ore to place
  oreType = config.getParameter("oreType")  -- The name of the matmod to place
  oreChance = config.getParameter("oreChance")  -- The probability of the circle appearing.
end

function destroy()
  oldDestroy()
  
  -- Do this with a probability of oreChance
  if math.random() < oreChance then
    -- Create a circle of matmods.
    for x = -radius, radius do
      for y = -radius, radius do
        if vec2.mag({x, y}) <= radius then
          world.placeMod(vec2.add(mcontroller.position(), {x, y}), "foreground", oreType)
        end
      end
    end
  end
end