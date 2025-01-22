---Utility coroutine functions related to movement.
vMovementA = {}

---Flies to be within `tolerance` distance of position `position` using `speed` and `controlForce`.
---@param pos Vec2F
---@param speed number? the speed at which to fly to the position. Defaults to `flySpeed`
---@param controlForce number? the control force to use when flying to the position. Defaults to `airForce`
---@param tolerance number? the maximum distance necessary to consider the entity "at" the target position. Defaults to 1
function vMovementA.flyToPosition(pos, speed, controlForce, tolerance)
  speed = speed or mcontroller.baseParameters().flySpeed
  controlForce = controlForce or mcontroller.baseParameters().airForce
  tolerance = tolerance or 1
  local distance
  repeat
    distance = world.distance(pos, mcontroller.position())
    mcontroller.controlApproachVelocity(vec2.mul(vec2.norm(distance), speed), controlForce)
    coroutine.yield()
  until math.abs(distance[1]) < tolerance and math.abs(distance[2]) < tolerance
end

---Flies to a given `position` with a provided `speed` and `tolerance` as well as `controlForce`, rotating "body" toward
---the target.
---@param pos Vec2F the position to fly to
---@param speed number? the speed at which to fly to the position. Defaults to `flySpeed`
---@param controlForce number? the control force to use when flying to the position. Defaults to `airForce`
---@param tolerance number? the maximum distance necessary to consider the entity "at" the target position. Defaults to 1
function vMovementA.rotatedFlyToPosition(pos, speed, controlForce, tolerance)
  speed = speed or mcontroller.baseParameters().flySpeed
  controlForce = controlForce or mcontroller.baseParameters().airForce
  tolerance = tolerance or 1
  local atPos

  while not atPos do
    atPos = vMovementA.rotatedFlyToPositionTick(pos, speed, controlForce, tolerance)

    coroutine.yield(nil)
  end
end

---Similar to `vMovementA.rotatedFlyToPosition`, except it flies to the position for one tick and returns `true` if the
---entity is within `tolerance` (in both axes) of the target position, `false` otherwise.
---@param pos Vec2F the position to fly to
---@param speed number the speed at which to fly to the position
---@param controlForce number the control force to use when flying to the position
---@param tolerance number the maximum distance necessary to consider the entity "at" the target position
function vMovementA.rotatedFlyToPositionTick(pos, speed, controlForce, tolerance)
  -- Approach velocity necessary to reach the target position
  local distance = world.distance(pos, mcontroller.position())
  mcontroller.controlApproachVelocity(vec2.mul(vec2.norm(distance), speed), controlForce)

  -- Rotate to current velocity
  local rotation = vec2.angle(mcontroller.velocity())
  mcontroller.setRotation(rotation)
  animator.resetTransformationGroup("body")
  animator.rotateTransformationGroup("body", rotation)

  mcontroller.controlFace(1)

  return math.abs(distance[1]) < tolerance and math.abs(distance[2]) < tolerance
end

---Stops the current entity with a force of `stopForce.
---@param stopForce number
function vMovementA.stop(stopForce)
  while vec2.mag(mcontroller.velocity()) > 0 do
    mcontroller.controlApproachVelocity({0, 0}, stopForce)
    coroutine.yield()
  end
end