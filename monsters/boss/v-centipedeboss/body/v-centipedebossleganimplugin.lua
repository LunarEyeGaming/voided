require "/scripts/v-ellipse.lua"

local oldInit = init or function() end
local oldUpdate = update or function() end

-- Maxmimum number of blocks that the leg is allowed to reach. Must not exceed leftLegUpperLength + leftLegLowerLength,
-- or rightLegUpperLength + rightLegLowerLength, whichever is smaller.
local maxLegSpan

-- The number of blocks from a leg forward center that the leg must reach. Should be small enough such that the distance
-- from the leg hip to the leg tip does not ever exceed maxLegSpan. The first value is the horizontal radius of the
-- ellipse. The second value is the vertical radius of the ellipse. "Horizontal" and "vertical" are relative to the
-- controller's current rotation.
local legForwardRadius

-- All of these are affected by the current rotation of the controller, where applicable
local leftLegHipOffset  -- Offset of start of left leg
local leftLegUpperLength  -- Length of upper part of leg
local leftLegLowerLength  -- Length of lower part of leg
-- A point relative to the left leg hip position designating the center of the leg reaching area
local leftLegForwardCenter
local leftLegMoveTime

local rightLegHipOffset
local rightLegUpperLength
local rightLegLowerLength
-- A point relative to the right leg hip position designating the center of the leg reaching area
local rightLegForwardCenter
local rightLegMoveTime

local leftLegHipPosition
local rightLegHipPosition

local leftLegPosition
local rightLegPosition
local leftLegMoveTimer  -- The amount of time remaining for the left leg's movement. Set to nil if it is not moving
local rightLegMoveTimer  -- The amount of time remaining for the right leg's movement. Set to nil if it is not moving
local prevLeftLegOffset  -- Position of the left leg tip relative to the left hip
local prevRightLegOffset  -- Position of the right leg tip relative to the right hip

function init()
  oldInit()

  maxLegSpan = animator.partProperty("body", "maxLegSpan")

  legForwardRadius = animator.partProperty("body", "legForwardRadius")

  leftLegHipOffset = animator.partProperty("upperleftleg", "hipPoint")
  leftLegUpperLength = animator.partProperty("upperleftleg", "length")
  leftLegLowerLength = animator.partProperty("lowerleftleg", "length")
  leftLegForwardCenter = animator.partProperty("upperleftleg", "forwardCenter")
  leftLegMoveTime = animator.partProperty("upperleftleg", "moveTime")

  rightLegHipOffset = animator.partProperty("upperrightleg", "hipPoint")
  rightLegUpperLength = animator.partProperty("upperrightleg", "length")
  rightLegLowerLength = animator.partProperty("lowerrightleg", "length")
  rightLegForwardCenter = animator.partProperty("upperrightleg", "forwardCenter")
  rightLegMoveTime = animator.partProperty("upperrightleg", "moveTime")

  prevPosition = mcontroller.position()
  prevPosition2 = prevPosition
  prevPosition3 = prevPosition2

  updateHipPositions()

  leftLegPosition = getNextLegPosition(leftLegForwardCenter, leftLegHipPosition)
  rightLegPosition = getNextLegPosition(rightLegForwardCenter, rightLegHipPosition)
  leftLegMoveTimer = nil
  rightLegMoveTimer = nil
end

function update(dt)
  oldUpdate(dt)

  updateLegs(dt)

  -- animator.rotateTransformationGroup("lefthipjoint", 0.01)
  -- animator.rotateTransformationGroup("leftkneejoint", 0.02, animator.partProperty("lowerleftleg", "kneePoint"))

  -- debugLeg()

  -- We keep track of previous positions up to three ticks in the past to measure the change in position more accurately
  prevPosition3 = prevPosition2
  prevPosition2 = prevPosition
  prevPosition = mcontroller.position()
end

---Updates the legs
---@param dt number
function updateLegs(dt)
  -- If the left leg is not currently moving to a new position...
  if not leftLegMoveTimer then
    updateLeftLegTransform(leftLegPosition)
  else
    local prevLeftLegPosition = vec2.add(leftLegHipPosition, vec2.rotate(prevLeftLegOffset, mcontroller.rotation()))

    -- Update left leg position
    leftLegPosition = getNextLegPosition(leftLegForwardCenter, leftLegHipPosition)

    -- world.debugLine(leftLegHipPosition, prevLeftLegPosition, "yellow")
    -- world.debugLine(leftLegHipPosition, leftLegPosition, "blue")

    -- Move the leg toward the next position.
    local legPos = vec2.lerp(leftLegMoveTimer / leftLegMoveTime, prevLeftLegPosition, leftLegPosition)
    updateLeftLegTransform(legPos)

    leftLegMoveTimer = leftLegMoveTimer + dt

    -- If at least leftLegMoveTime seconds have elapsed...
    if leftLegMoveTimer >= leftLegMoveTime then
      animator.playSound("step")

      -- Signal that the left leg has stopped moving.
      leftLegMoveTimer = nil
    end
  end

  -- If the right leg is not currently moving to a new position...
  if not rightLegMoveTimer then
    updateRightLegTransform(rightLegPosition)
  else
    local prevRightLegPosition = vec2.add(rightLegHipPosition, vec2.rotate(prevRightLegOffset, mcontroller.rotation()))

    -- Update right leg position
    rightLegPosition = getNextLegPosition(rightLegForwardCenter, rightLegHipPosition)

    -- Move the leg toward the next position. Cap the ratio at 1.0 to avoid slight overshooting.
    local legPos = vec2.lerp(math.min(1.0, rightLegMoveTimer / rightLegMoveTime), prevRightLegPosition, rightLegPosition)
    updateRightLegTransform(legPos)

    rightLegMoveTimer = rightLegMoveTimer + dt

    -- If at least leftLegMoveTime seconds have elapsed...
    if rightLegMoveTimer >= rightLegMoveTime then
      animator.playSound("step")

      -- Signal that the right leg has stopped moving.
      rightLegMoveTimer = nil
    end
  end

  -- Store the relative positions of the leg tips BEFORE updateHipPositions is called because when animating leg steps,
  -- the absolute positions will have already been invalidated because they exceed maxLegSpan. Also check if
  -- the move timers are defined before doing so to avoid unnecessarily redefining the offsets.
  if not leftLegMoveTimer then
    prevLeftLegOffset = vec2.rotate(world.distance(leftLegPosition, leftLegHipPosition), -mcontroller.rotation())
  end

  if not rightLegMoveTimer then
    prevRightLegOffset = vec2.rotate(world.distance(rightLegPosition, rightLegHipPosition), -mcontroller.rotation())
  end

  updateHipPositions()

  -- If the left leg is not currently moving and its leg span exceeds the maximum...
  if not leftLegMoveTimer and getLegSpan(leftLegPosition, leftLegHipPosition) > maxLegSpan then
    -- Start leg movement animation
    leftLegMoveTimer = 0
  end

  -- If the right leg is not currently moving and its leg span exceeds the maximum...
  if not rightLegMoveTimer and getLegSpan(rightLegPosition, rightLegHipPosition) > maxLegSpan then
    -- Start leg movement animation
    rightLegMoveTimer = 0
  end
end

---Applies the left leg transformations for the current tick, with the leg pointing at `legPos`
---@param legPos Vec2F the position to which the leg should point
function updateLeftLegTransform(legPos)
  -- world.debugLine(leftLegHipPosition, legPos, "green")
  -- Compensate for current controller rotation here, as well as a base rotation of 90 degrees
  local baseLeftAngle = vec2.angle(world.distance(legPos, leftLegHipPosition)) - mcontroller.rotation() - math.pi / 2

  -- Calculate leg angles
  local leftLegSpan = getLegSpan(legPos, leftLegHipPosition)
  local leftHipAngle, leftKneeAngle = getLegAngles(leftLegSpan, leftLegUpperLength, leftLegLowerLength)

  animator.resetTransformationGroup("lefthipjoint")
  animator.resetTransformationGroup("leftkneejoint")
  animator.rotateTransformationGroup("lefthipjoint", baseLeftAngle + leftHipAngle, vec2.rotate(leftLegHipOffset, mcontroller.rotation()))
  animator.rotateTransformationGroup("leftkneejoint", leftKneeAngle, animator.partProperty("lowerleftleg", "kneePoint"))
end

---Applies the right leg transformations for the current tick, with the leg pointing at `legPos`
---@param legPos Vec2F the position to which the leg should point
function updateRightLegTransform(legPos)
  -- world.debugLine(rightLegHipPosition, legPos, "green")
  -- Compensate for current controller rotation here, as well as a base rotation of -90 degrees
  local baseRightAngle = vec2.angle(world.distance(legPos, rightLegHipPosition)) - mcontroller.rotation() + math.pi / 2

  -- Calculate leg angles
  local rightLegSpan = getLegSpan(legPos, rightLegHipPosition)
  local tempHipAngle, tempKneeAngle = getLegAngles(rightLegSpan, rightLegUpperLength, rightLegLowerLength)
  -- The right angles are simply negations of the left.
  local rightHipAngle, rightKneeAngle = -tempHipAngle, -tempKneeAngle
  animator.resetTransformationGroup("righthipjoint")
  animator.resetTransformationGroup("rightkneejoint")
  animator.rotateTransformationGroup("righthipjoint", baseRightAngle + rightHipAngle, vec2.rotate(rightLegHipOffset, mcontroller.rotation()))
  animator.rotateTransformationGroup("rightkneejoint", rightKneeAngle, animator.partProperty("lowerrightleg", "kneePoint"))
end

---Updates the absolute positions of the leg hips.
function updateHipPositions()
  leftLegHipPosition = vec2.add(mcontroller.position(), vec2.rotate(leftLegHipOffset, mcontroller.rotation()))
  rightLegHipPosition = vec2.add(mcontroller.position(), vec2.rotate(rightLegHipOffset, mcontroller.rotation()))
end

---Returns the distance from the start of the leg to the end of it.
---@return number
function getLegSpan(legPosition, legHipPosition)
  return world.magnitude(legPosition, legHipPosition)
end

---Returns the next leg end position. The calculations account for the hip position of the leg `legHipPosition`, the
---forward center of the leg `forwardCenter`, the `legForwardRadius` variable, and the current rotation of the
---controller.
---@param forwardCenter Vec2F
---@param legHipPosition Vec2F
---@return Vec2F
function getNextLegPosition(forwardCenter, legHipPosition)
  -- Get where the controller is heading.
  local headingAngle = vec2.angle(world.distance(mcontroller.position(), prevPosition3))

  -- world.debugLine(mcontroller.position(), vec2.add(mcontroller.position(), vec2.withAngle(headingAngle, 10)), "magenta")
  -- world.debugPoint(vec2.add(mcontroller.position(), vec2.withAngle(headingAngle, 10)), "magenta")

  -- Get the heading direction as if the current rotation is 0.
  local standardizedHeadingAngle = headingAngle - mcontroller.rotation()

  -- Get a point on an ellipse at angle standardizedHeadingAngle with vector radius legForwardRadius
  local ellipsePoint = {
    legForwardRadius[1] * math.cos(standardizedHeadingAngle),
    legForwardRadius[2] * math.sin(standardizedHeadingAngle)
  }

  -- Rotate the point by mcontroller.rotation()
  local rotatedEllipsePoint = vec2.rotate(ellipsePoint, mcontroller.rotation())

  -- Final point: Offset by forwardCenter (which accounts for the current rotation), relative to the leg hip position.
  return vec2.add(
    legHipPosition,
    vec2.add(
      vec2.rotate(forwardCenter, mcontroller.rotation()),
      rotatedEllipsePoint
    )
  )
end

---Returns the angles of the upper and lower legs respectively based on `legSpan`, `legUpperLength`, and
---`legLowerLength`.
---@param legSpan number the distance from the leg hip to the leg tip
---@param legUpperLength number the length of the upper component of the leg
---@param legLowerLength number the length of the lower component of the leg
---@return number
---@return number
function getLegAngles(legSpan, legUpperLength, legLowerLength)
  local upperAngle = math.acos((legUpperLength ^ 2 + legSpan ^ 2 - legLowerLength ^ 2) / (2 * legUpperLength * legSpan))
  -- Subtract math.pi from the initial result to get clockwise rotation from pointing outward instead of
  -- counterclockwise rotation from pointing inward
  local lowerAngle = math.acos((legUpperLength ^ 2 + legLowerLength ^ 2 - legSpan ^ 2) / (2 * legUpperLength * legLowerLength)) - math.pi

  return upperAngle, lowerAngle
end

---Shows two ellipses. The first one signifies the possible return values of getNextLegPosition. The second one
---signifies the reach area of the leg set by maxLegSpan. Use this function to make sure that the animation parameters
---are correctly configured (i.e., the first ellipse is completely inside of the second ellipse).
function debugLeg()
  local numPoints = 50
  local points = {}
  for i = 1, numPoints do
    local headingAngle = i / numPoints * 2 * math.pi
    -- Get the heading direction as if the current rotation is 0.
    local standardizedHeadingAngle = headingAngle - mcontroller.rotation()

    -- Get a point on an ellipse at angle standardizedHeadingAngle with vector radius legForwardRadius
    local ellipsePoint = {
      legForwardRadius[1] * math.cos(standardizedHeadingAngle),
      legForwardRadius[2] * math.sin(standardizedHeadingAngle)
    }

    -- Rotate the point by mcontroller.rotation()
    local rotatedEllipsePoint = vec2.rotate(ellipsePoint, mcontroller.rotation())

    -- Final point: Offset by forwardCenter (which accounts for the current rotation), relative to the leg hip position.
    table.insert(points, vec2.add(
      leftLegHipPosition,
      vec2.add(
        vec2.rotate(leftLegForwardCenter, mcontroller.rotation()),
        rotatedEllipsePoint
      )
    ))
  end

  world.debugPoly(points, "green")

  vEllipse.debug(leftLegHipPosition, {maxLegSpan, maxLegSpan}, numPoints, "red")
end