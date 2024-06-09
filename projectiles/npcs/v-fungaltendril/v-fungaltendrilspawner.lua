--[[
  Script for the projectile that spawns a wave of projectiles. The direction of the wave is determined by the 
  groundNormalAngle variable, which is an angle whose corresponding vector points perpendicular (or normal) to the
  ground, and it equals the projectile's current rotation. Thus, the "horizontal" direction is parallel to the ground,
  and the "vertical" direction is parallel to the groundNormal vector. This relationship applies to related terms like
  altitude as well.

  The wave grows outward in either direction at a rate based on spawnInterval and gapSize until it reaches 2 * waveSize
  blocks in width, in which case the current projectile dies. The wave projectiles start at gapSize blocks in distance
  and will grow in horizontal distance by gapSize each time that they are spawned. Their altitudes adjust to the
  surrounding terrain, up to maxHeight and down to minHeight. If the altitude on either side exceeds these boundaries,
  the wave on the corresponding side will stop. If both sides stop, then the projectile dies. projectileType and
  projectileParameters determine the type of projectile to spawn and its parameter overrides respectively. After the
  first projectile is spawned, minHeight and maxHeight will now be relative to the heights at which the previous
  projectiles spawned (which, in turn, have values relative to the current projectile's vertical position and are
  vectors).
  
  The update function ensures that the projectile does not ever die until the script tells it to by repeatedly setting
  the time to live to 1.0 if it exceeds 0.5. These values are almost entirely arbitrary. All that matters is that the
  former must be greater than the latter, which in turn must be greater than zero. This ensures that the projectile will
  always have a positive time to live (except when the projectile needs to die--projectile.die() simply sets the time to
  live to 0).
]]

require "/scripts/util.lua"
require "/scripts/vec2.lua"

local groundNormalAngle  -- An angle whose corresponding vector points perpendicular to the ground
local groundNormal  -- The aforementioned vector
local gapSize  -- The horizontal distance between each projectile
local maxHeight  -- Maximum altitude relative to the projectile's position and to the height of the previous projectile
local minHeight  -- Minimum altitude relative to the projectile's position and to the height of the previous projectile
local projectileParameters  -- The parameter overrides of the projectile to spawn
local projectileType  -- The type of projectile to spawn
local spawnInterval  -- Amount of time (in seconds) between each projectile spawn
local waveSize  -- The overall size of the wave in blocks.
local inheritDamageFactor  -- If defined, the multiplier of the spawned projectile's power to use relative to the 
                           -- current projectile's power
local waveFuzzAngle  -- A value representing the range of angles at which the projectile can spawn relative to its
                     -- initial angle. Defaults to 0.

local spawnTimer  -- Current amount of time remaining before the next pair of projectiles spawns.
local hOffset  -- Current horizontal offset of the projectiles

local leftStopped  -- Whether or not the left side of the wave stopped
local rightStopped -- Whether or not the right side of the wave stopped

local prevHeightLeft  -- Previous height vector on the left side of the wave
local prevHeightRight  -- Previous height vector on the right side of the wave
local prevCollisionPointLeft
local prevCollisionPointRight

function init()
  groundNormalAngle = mcontroller.rotation()
  groundNormal = vec2.rotate({1, 0}, groundNormalAngle)
  gapSize = config.getParameter("gapSize")
  maxHeight = config.getParameter("maxHeight")
  minHeight = config.getParameter("minHeight")
  projectileParameters = config.getParameter("projectileParameters", {})
  projectileType = config.getParameter("projectileType")
  spawnInterval = config.getParameter("spawnInterval")
  waveSize = config.getParameter("waveSize")
  inheritDamageFactor = config.getParameter("inheritDamageFactor")
  waveFuzzAngle = util.toRadians(config.getParameter("waveFuzzAngle", 0))
  
  -- If inheritDamageFactor is defined...
  if inheritDamageFactor then
    -- Adjust the power of the spawned projectile.
    projectileParameters.power = projectile.power() * inheritDamageFactor
  end
  
  spawnTimer = spawnInterval
  hOffset = gapSize

  leftStopped = false
  rightStopped = false
  
  prevHeightLeft = {0, 0}
  prevHeightRight = {0, 0}
  prevCollisionPointLeft = mcontroller.position()
  prevCollisionPointRight = mcontroller.position()
  
  mcontroller.setVelocity({0, 0})
  
  -- currentRotation = 0
end

-- A function called every scriptDelta / 60 seconds.
function update(dt)
  -- If the timeToLive is greater than 0.5...
  if projectile.timeToLive() > 0.5 then
    -- Set the timeToLive to 1.0.
    projectile.setTimeToLive(1.0)
  end

  spawnTimer = spawnTimer - dt
  
  -- If the spawn timer has reached zero...
  if spawnTimer <= 0 then
    spawnWaveProjectile(true)  -- Spawn projectile on left side
    spawnWaveProjectile(false)  -- Spawn projectile on right side

    spawnTimer = spawnInterval  -- Reset timer

    hOffset = hOffset + gapSize  -- Nudge horizontal offset
    
    -- If the horizontal offset exceeds waveSize or both leftStopped and rightStopped are true...
    if hOffset > waveSize or (leftStopped and rightStopped) then
      projectile.die()  -- Kill the current projectile
    end
  end
  
  -- currentRotation = currentRotation + math.pi / 4 * dt
  -- mcontroller.setRotation(currentRotation)
  -- groundNormalAngle = mcontroller.rotation()
  -- groundNormal = vec2.rotate({1, 0}, groundNormalAngle)
  
  -- ranIntoBarrier(mcontroller.position(), vec2.add(mcontroller.position(), vec2.rotate({5, 2}, mcontroller.rotation()), 0.25))
  -- ranIntoBarrier(mcontroller.position(), vec2.add(mcontroller.position(), vec2.rotate({5, -2}, mcontroller.rotation()), 0.25))
  -- ranIntoBarrier(mcontroller.position(), vec2.add(mcontroller.position(), vec2.rotate({-5, -2}, mcontroller.rotation()), 0.25))
  -- ranIntoBarrier(mcontroller.position(), vec2.add(mcontroller.position(), vec2.rotate({-5, 2}, mcontroller.rotation()), 0.25))
  
  -- world.debugLine(mcontroller.position(), vec2.add(mcontroller.position(), vec2.withAngle(mcontroller.rotation())), "blue")
end

--[[
  Spawns the projectile for the left / right side, which is specified by a boolean `isLeft`. The position of the 
  projectile is based on `minHeight`, `maxHeight`, and `hOffset` and adjusts according to the terrain via geometry 
  collision tests. If the collision test fails (i.e., no terrain is found within the line from maxHeight to minHeight),
  then the corresponding variable for whether or not the side has stopped is set to true (`leftStopped` for left, 
  `rightStopped` for right). If `isLeft` is set to true, then `hOffset` is negated prior to doing any calculations.
  `projectileType` and `projectileParameters` are specified in `init()`. The projectile's direction is the ground
  normal and is randomly nudged by a value from `-waveFuzzAngle / 2` to `waveFuzzAngle / 2`, if `waveFuzzAngle` is
  defined.
  
  param (boolean) isLeft: whether or not the projectile spawns on the left side
]]
function spawnWaveProjectile(isLeft)
  local sidedHOffset = isLeft and -hOffset or hOffset  -- -hOffset if isLeft, hOffset otherwise
  -- If isLeft is true and left side has not stopped or isLeft is false and right side has not stopped...
  if (isLeft and not leftStopped) or (not isLeft and not rightStopped) then
    local prevCollisionPoint = isLeft and prevCollisionPointLeft or prevCollisionPointRight
    -- The midpoint of the collision test points.
    local center = vec2.add(mcontroller.position(), isLeft and prevHeightLeft or prevHeightRight)

    -- Get upper collision test point by forming a vector that acts as if the ground normal is {1, 0} (so x and y are
    -- swapped), rotating it by groundNormalAngle, and adding the center to it to get the absolute position.
    local collisionPointTop = vec2.add(vec2.rotate({maxHeight, sidedHOffset}, groundNormalAngle), center)
    local collisionPointMid = vec2.add(vec2.rotate({0, sidedHOffset}, groundNormalAngle), center)
    -- Get the other collision test point by repeating the previous instructions like so (but for minHeight instead).
    local collisionPointBottom = vec2.add(vec2.rotate({minHeight, sidedHOffset}, groundNormalAngle), center)
    
    -- Run two collision tests. One from middle to bottom and another from top to middle. This favors downward-moving 
    -- terrain.
    local collisionPoint = world.lineCollision(collisionPointMid, collisionPointBottom)
    -- If a collision point is not defined or the wave runs into a barrier while going downward...
    if not collisionPoint or ranIntoBarrier(collisionPoint, prevCollisionPoint, 0.25) then
      collisionPoint = world.lineCollision(collisionPointTop, collisionPointMid)
    end

    -- If the collision point is defined and the wave has not run into a barrier...
    if collisionPoint and not ranIntoBarrier(collisionPoint, prevCollisionPoint, 0.25) then
      -- Aim vector is -90 degrees from the normal, plus a random float value from -waveFuzzAngle / 2 to waveFuzzAngle 
      -- / 2
      local aimVector = vec2.rotate(groundNormal, -math.pi / 2 + math.random() * waveFuzzAngle - waveFuzzAngle / 2)
      world.spawnProjectile(projectileType, collisionPoint, projectile.sourceEntity(), aimVector, false,
          projectileParameters)
      
      -- The prev height vector is the projection of the distance from the current projectile's position to the
      -- collision point onto the ground normal.
      local prevHeight = projectVector(world.distance(collisionPoint, mcontroller.position()), groundNormal)

      -- Set prevHeightLeft or prevHeightRight, depending on direction.
      if isLeft then
        prevHeightLeft = prevHeight
        prevCollisionPointLeft = collisionPoint
      else
        prevHeightRight = prevHeight
        prevCollisionPointRight = collisionPoint
      end
    else
      -- If this is the left side...
      if isLeft then
        -- Left is stopped.
        leftStopped = true
      else
        -- Right is stopped
        rightStopped = true
      end
    end
  end
end

--[[
  Performs a line collision test with the two points `point1` and `point2`, each nudged along the `groundNormal` vector
  by `nudgeAmount`. Also performs two more collision tests by forming a right triangle that has one side parallel to
  the `groundNormal` vector. The placement of the third point in this triangle will always be horizontally aligned with
  `point1` if the change in vertical position from `point1` to `point2` is positive and with `point2` otherwise. This
  function returns true if all of these tests succeed, false otherwise. When `groundNormal` is {0, 1}, the following
  visualizes the lines that are checked depending on quadrant:

   II *--*--* I
       \ | /
        \|/
      *--*--*
      | / \ |
      |/   \|
  III *     * IV
  
  param (Vec2F) point1: the first point in the line collision test
  param (Vec2F) point2: the second point in the line collision test
  param (number) nudgeAmount: the amount by which to nudge the vectors along the `groundNormal` vector, in blocks
]]
function ranIntoBarrier(point1, point2, nudgeAmount)
  local nudgeVector = vec2.withAngle(groundNormalAngle, nudgeAmount)
  local point1Nudged = vec2.add(point1, nudgeVector)
  local point2Nudged = vec2.add(point2, nudgeVector)
  
  -- Get the change in height (as a vector). This is not relative to the coordinate system rotated to `groundNormal` and
  -- is instead relative to the standard coordinate system.
  local heightChange = projectVector(world.distance(point2Nudged, point1Nudged), groundNormal)
  -- This is a number representing the change in height within the coordinate system that is rotated to `groundNormal`.
  local heightChangeAbsolute = vec2.rotate(heightChange, -groundNormalAngle)[1]
  
  -- world.debugLine(vec2.add(nudgeVector, mcontroller.position()), vec2.add(nudgeVector, vec2.add(mcontroller.position(), {heightChangeAbsolute, 0})), "red")
  -- world.debugPoint(vec2.add(nudgeVector, vec2.add(mcontroller.position(), {heightChangeAbsolute, 0})), "red")
  
  local point3Nudged

  -- If the change in height is positive...
  if heightChangeAbsolute > 0 then
    -- This expression derives a third point to form a right triangle with the vertically-oriented line being parallel 
    -- to the `groundNormal` vector.
    point3Nudged = vec2.add(heightChange, point1Nudged)
  else
    -- This does the same thing, except it's the opposite corner this time
    point3Nudged = vec2.add(vec2.mul(heightChange, -1), point2Nudged)
  end

  world.debugLine(point1Nudged, point2Nudged, "green")

  world.debugLine(point1Nudged, point3Nudged, "green")
  world.debugLine(point2Nudged, point3Nudged, "green")
  
  return world.lineCollision(point1Nudged, point2Nudged)
    -- Rectangle tests
    and world.lineCollision(point1Nudged, point3Nudged) and world.lineCollision(point2Nudged, point3Nudged)
end

-- --[[
  -- Returns true if either horizontalLineCollision or lineCollisionNudged succeeded, false otherwise.
  
  -- param (Vec2F) point1: the first point in the line collision test. Used in horizontalLineCollision and
    -- lineCollisionNudged
  -- param (Vec2F) point2: the second point in the line collision test. Used in lineCollisionNudged
  -- param (number) hNudgeAmount: the amount by which to nudge the vectors perpendicular to the `groundNormal` vector, in
    -- blocks. Used in horizontalLineCollision.
  -- param (number) vNudgeAmount: the amount by which to nudge the vectors along the `groundNormal` vector, in blocks. Used
    -- in horizontalLineCollision and lineCollisionNudged
-- ]]
-- function ranIntoBarrier(point1, point2, hNudgeAmount, vNudgeAmount)
  -- return lineCollisionNudged(point1, point2, vNudgeAmount) or horizontalLineCollision(point1, hNudgeAmount, vNudgeAmount)
-- end

--[[
  Returns the projection of vector `vector` onto vector `ontoVector`.
  
  param vector: the vector to project
  param ontoVector: the vector onto which to project
  returns: the projection of `vector` onto `ontoVector`.
]]
function projectVector(vector, ontoVector)
  return vec2.mul(
    ontoVector,
    vec2.dot(
      vector,
      ontoVector
    ) / (vec2.mag(ontoVector) ^ 2)
  )
end