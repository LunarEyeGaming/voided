require "/scripts/vec2.lua"
require "/scripts/rect.lua"

local oldInit = init or function() end
local oldUpdate = update or function() end

local oldPositions
local stutterTimer
local prevPosition

function init()
  oldInit()

  oldPositions = {}
  stutterTimer = nil
end

function update(dt)
  oldUpdate(dt)
  local pos = mcontroller.position()
  if #oldPositions > 2 then
    table.remove(oldPositions, 1)
  end
  table.insert(oldPositions, pos)

  if math.random() < 0.1 and not stutterTimer then
    -- prevPosition = mcontroller.position()
    -- mcontroller.setPosition(oldPositions[1])
    stutterTimer = 0.03
  end

  if stutterTimer then
    stutterTimer = stutterTimer - dt
    mcontroller.setVelocity({0, 0})
    if stutterTimer <= 0 then
      -- mcontroller.setPosition(prevPosition)
      stutterTimer = nil
    end
  end
end