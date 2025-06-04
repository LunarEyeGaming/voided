require "/scripts/vec2.lua"
require "/scripts/util.lua"

require "/scripts/v-world.lua"

-- TODO: Fix issue encountered due to world wrap.

local DIRECTIONS = {{1, 0}, {1, 1}, {0, 1}, {-1, 1}, {-1, 0}, {-1, -1}, {0, -1}, {1, -1}}

local trailProjectileType  ---@type string
local trailProjectileParameters  ---@type Json
local trailVerticalOffset  ---@type number

local currentDirectionIdx  ---@type integer
local preferredDirection  ---@type integer
local prevCollidePointLeft  ---@type boolean

function init()
  trailProjectileType = "v-sunleapershockwavetrail"
  trailProjectileParameters = {
    power = projectile.power(),
    powerMultiplier = projectile.powerMultiplier()
  }
  trailVerticalOffset = 0.625

  local startRotation = util.wrapAngle(mcontroller.rotation())

  -- Choose currentDirectionIdx value to use based on current rotation.
  for i = 1, #DIRECTIONS do
    if vec2.angle(DIRECTIONS[i]) <= startRotation and startRotation <= vec2.angle(DIRECTIONS[i % #DIRECTIONS + 1]) then
      currentDirectionIdx = i
      break
    end
  end

  -- Default
  if not currentDirectionIdx then
    currentDirectionIdx = 1
  end
  preferredDirection = 1

  mcontroller.setPosition({math.floor(mcontroller.position()[1]) + 0.5, math.floor(mcontroller.position()[2]) + 0.5})
end

function update(dt)
  local nextPos, nextDirIdx = getNextPos(mcontroller.position())

  -- If a next position was found...
  if nextPos then
    currentDirectionIdx = nextDirIdx  -- Set currentDirectionIdx

    -- If the current direction is diagonal...
    if currentDirectionIdx % 2 == 0 then
      local nudgeTestDirection
      if prevCollidePointLeft then
        nudgeTestDirection = 1  -- Counterclockwise
      else
        nudgeTestDirection = -1  -- Clockwise
      end
      local nudgeTest, nudgedDirection = getDirection(currentDirectionIdx + nudgeTestDirection)
      -- Determine whether to nudge the direction of the projectile.
      if not world.pointCollision(vec2.add(nextPos, nudgeTest)) then
        currentDirectionIdx = nudgedDirection
      end
    end

    local leftDirection = getDirection(currentDirectionIdx + 2)  -- 90 degrees CCW
    local collidePointLeft = world.pointCollision(vec2.add(nextPos, vec2.mul(leftDirection, 1.5)))

    -- Determine shockwave direction as well as preferred direction
    local shockwaveDirection, shockwaveIdx
    if collidePointLeft then
      shockwaveDirection, shockwaveIdx = getDirection(currentDirectionIdx + 4)  -- 180 degrees
      preferredDirection = 1
    else
      shockwaveDirection, shockwaveIdx = DIRECTIONS[currentDirectionIdx], currentDirectionIdx
      preferredDirection = -1
    end

    local offsetDir = getDirection(shockwaveIdx + 2)
    local projectilePos = vec2.add(nextPos, vec2.mul(offsetDir, trailVerticalOffset))
    world.spawnProjectile(trailProjectileType, projectilePos, projectile.sourceEntity(), shockwaveDirection, false, trailProjectileParameters)

    mcontroller.setRotation(vec2.angle(DIRECTIONS[currentDirectionIdx]))  -- Update rotation
    mcontroller.setPosition(nextPos)

    prevCollidePointLeft = collidePointLeft
  end
end

---Returns the direction at index `index` followed by the wrapped index.
---@param index integer
---@return Vec2F
---@return integer
function getDirection(index)
  local wrappedIdx = (index - 1) % #DIRECTIONS + 1
  -- Wrapped index access
  return DIRECTIONS[wrappedIdx], wrappedIdx
end

---Returns the next position to go to and the corresponding index used to test it.
---@param pos Vec2F
---@return table?
---@return integer?
function getNextPos(pos)
  -- Search through all possible directions for an empty position adjacent to at least one block.
  for i = 0, #DIRECTIONS do
    -- Alternate between counterclockwise and clockwise rotation (as directions are ordered in a counterclockwise
    -- manner).
    local multiplier
    if i % 2 == 0 then
      multiplier = preferredDirection
    else
      multiplier = -preferredDirection
    end
    -- We integer-divide i by 2 to avoid skipping any positions.
    local testDirection, testIdx = getDirection(currentDirectionIdx + i // 2 * multiplier)

    -- Get corresponding direction and add it to pos to get the test position.
    local testPos = vec2.add(pos, testDirection)

    -- Handle special cases like:
    -- #####<
    --      #############
    -- where the entity is heading leftwards and may slip through a diagonal gap.
    -- The result should be:
    --     *
    -- #####
    --      #############
    -- and not
    -- #####
    --     *#############
    local passedSpecialCase = true
    if testIdx % 2 == 0 then
      local testDirection2 = getDirection(testIdx + 1)
      local testDirection3 = getDirection(testIdx - 1)
      local testPos2 = vec2.add(pos, testDirection2)
      local testPos3 = vec2.add(pos, testDirection3)

      if world.pointCollision(testPos2) and world.pointCollision(testPos3) then
        passedSpecialCase = false
      end
    end

    -- If the position is empty and is adjacent to some tiles...
    if passedSpecialCase and not world.pointCollision(testPos) and vWorld.isGroundAdjacent(testPos) then
      return testPos, testIdx
    end
  end
end