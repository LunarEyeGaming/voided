require "/scripts/vec2.lua"

--[[
  Forces liquid to stay below a certain level. The levelRangeInterval is to be used if the liquid is being drained too
  quickly.
]]

local levelRange  -- Horizontal range of the area affected by the leveler
local levelRangeInterval  -- The distance between each block scanned for a liquid
local sensorAltitude  -- The vertical position at which to scan for a liquid
local drainAltitude  -- The vertical position at which to remove the liquid.

function init()
  levelRange = config.getParameter("levelRange")
  levelRangeInterval = config.getParameter("levelRangeInterval")
  sensorAltitude = config.getParameter("sensorAltitude")
  drainAltitude = config.getParameter("drainAltitude")
end

function update(dt)
  -- Scans the area for liquid above the level and removes the liquid at the corresponding block if necessary.
  for x = levelRange[1], levelRange[2], levelRangeInterval do
    local sensorOffset = {x, sensorAltitude}
    local drainOffset = {x, drainAltitude}
    
    -- Check for liquid
    if world.liquidAt(vec2.add(object.position(), sensorOffset)) then
      -- Destroy at the corresponding block (which can be separate)
      world.forceDestroyLiquid(vec2.add(object.position(), drainOffset))
    end
  end
end