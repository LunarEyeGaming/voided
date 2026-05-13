require "/scripts/v-time.lua"
require "/scripts/rect.lua"

-- Requires an object to be immersed in a certain amount of liquid, though it won't explode if it isn't in liquid for
-- one millisecond.

local destroyChance
local destroyDelay  -- Amount of time outside of liquid to wait before destroying.
local minimumImmersionLevel
local checkInterval
local destroyInterval  -- Time between each destruction attempt

local objectBounds
local destroyTimer

local oldInit = init or function() end
local oldUpdate = update or function() end

function init()
  oldInit()

  destroyChance = config.getParameter("softImmersion.destroyChance")
  destroyDelay = config.getParameter("softImmersion.destroyDelay")
  minimumImmersionLevel = config.getParameter("softImmersion.minimumLevel")
  checkInterval = config.getParameter("softImmersion.checkInterval")
  destroyInterval = config.getParameter("softImmersion.destroyInterval")

  objectBounds = rect.translate(calculateBoundBox(object.spaces()), object.position())
  destroyTimer = destroyDelay

  vTime.addInterval(checkInterval, checkImmersion)
  vTime.addInterval(destroyInterval, attemptDestruction)
end

function update(dt)
  oldUpdate(dt)

  destroyTimer = destroyTimer - dt

  vTime.update(dt)
end

---Returns the bounding box containing the given spaces
---@param spaces Vec2I[]
---@return RectI
function calculateBoundBox(spaces)
  local minX, minY, maxX, maxY
  minX = math.huge
  minY = math.huge
  maxX = -math.huge
  maxY = -math.huge

  -- Run through all spaces and determine the minimum and maximum coordinates.
  for _, space in ipairs(spaces) do
    if space[1] < minX then
      minX = space[1]
    end

    if space[1] > maxX then
      maxX = space[1]
    end

    if space[2] < minY then
      minY = space[2]
    end

    if space[2] > maxY then
      maxY = space[2]
    end
  end

  -- Increase max bounds by 1 to ensure that they properly cover the object
  maxX = maxX + 1
  maxY = maxY + 1

  return {minX, minY, maxX, maxY}
end

function checkImmersion()
  -- Total amount of the object's space occupied by liquids; total amount of the object's space occupied by the object
  -- itself.
  local liquidArea = 0
  local objectArea = 0
  local spaces = object.spaces()
  local ownPos = object.position()
  for _, space in ipairs(spaces) do
    local pos = vec2.add(ownPos, space)

    local liquidLevel = world.liquidAt(pos)
    if liquidLevel then
      liquidArea = liquidArea + liquidLevel[2]
    end
    objectArea = objectArea + 1
  end

  -- Average liquid
  local liquidImmersion = liquidArea / objectArea

  if liquidImmersion >= minimumImmersionLevel then
    destroyTimer = destroyDelay  -- Refresh timer
  end
end

function attemptDestruction()
  -- If the destroy delay has been spent...
  if destroyTimer <= 0 then
    -- Destroy with a chance of destroyChance
    if math.random() < destroyChance then
      object.smash()
    end
  end
end