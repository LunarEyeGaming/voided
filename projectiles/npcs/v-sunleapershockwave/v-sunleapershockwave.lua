require "/scripts/vec2.lua"
require "/scripts/util.lua"

require "/scripts/v-world.lua"

local directions = {{1, 0}, {1, 1}, {0, 1}, {-1, 1}, {-1, 0}, {-1, -1}, {0, -1}, {1, -1}}
local currentDirectionIdx

function init()
  local startRotation = util.wrapAngle(mcontroller.rotation())

  for i = 1, #directions do
    if vec2.angle(directions[i]) <= startRotation and startRotation <= vec2.angle(directions[i % #directions + 1]) then
      currentDirectionIdx = i
      break
    end
  end

  if not currentDirectionIdx then
    currentDirectionIdx = 1
  end

  mcontroller.setPosition({math.floor(mcontroller.position()[1]) + 0.5, math.floor(mcontroller.position()[2]) + 0.5})
end

function update(dt)
  local ownPos = mcontroller.position()

  local nextPos

  -- Search through all possible directions for an empty position adjacent to at least one block.
  for i = 0, #directions do
    -- Alternate between counterclockwise and clockwise rotation (as directions are ordered in a counterclockwise
    -- manner).
    local multiplier
    if i % 2 == 0 then
      multiplier = 1
    else
      multiplier = -1
    end
    -- We integer-divide i by 2 to avoid skipping any positions. Also apply modulus after offsetting to wrap around.
    local testIdx = (currentDirectionIdx + i // 2 * multiplier - 1) % #directions + 1

    -- Get corresponding direction and add it to ownPos to get the test position.
    local testPos = vec2.add(ownPos, directions[testIdx])

    -- If the position is empty and is adjacent to some tiles...
    if not world.pointCollision(testPos) and vWorld.isGroundAdjacent(testPos) then
      currentDirectionIdx = testIdx  -- Set currentDirectionIdx
      nextPos = testPos  -- Set next position
      mcontroller.setRotation(vec2.angle(directions[currentDirectionIdx]))  -- Update rotation
      break  -- Exit loop
    end
  end

  -- If a next position was found...
  if nextPos then
    mcontroller.setPosition(nextPos)
  else
    -- projectile.die()
  end
end