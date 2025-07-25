require "/scripts/util.lua"
require "/scripts/vec2.lua"

require "/scripts/v-behavior.lua"

-- param beamName
-- param active
function v_setLaserBeamActive(args)
  local rq = vBehavior.requireArgsGen("v_setLaserBeamActive", args)

  if not rq{"beamName", "active"} then return false end

  -- If the arguments specify to set the beam to active and the beam name is not already in enabledLaserBeams...
  if args.active and not contains(self.enabledLaserBeams, args.beamName) then
    -- Add it to the list of enabled beams.
    table.insert(self.enabledLaserBeams, args.beamName)
  -- Otherwise, if the arguments specify to set the beam to inactive...
  elseif not args.active then
    -- Delete the beam name from the list of enabled beams.
    self.enabledLaserBeams = util.filter(self.enabledLaserBeams, function(x) return x ~= args.beamName end)
  end
  -- Update the parameter.
  monster.setAnimationParameter("enabledBeams", self.enabledLaserBeams)

  return true
end

-- param speedThreshold
-- param warningSpeedThreshold
-- param transformationGroup
-- param flipTransformationGroup
-- param flipRotateTransformationGroup
-- param stateType
function v_speedEffect(args)
  local rq = vBehavior.requireArgsGen("v_speedEffect", args)
  if not rq{"stateType", "speedThreshold"} then return false end

  local velocity = mcontroller.velocity()
  local speed = vec2.mag(velocity)

  if speed > args.speedThreshold then
    animator.setAnimationState(args.stateType, "on")
  elseif args.warningSpeedThreshold and speed > args.warningSpeedThreshold then
    animator.setAnimationState(args.stateType, "warning")
  else
    animator.setAnimationState(args.stateType, "off")
  end


  if args.transformationGroup then
    local angle = vec2.angle(velocity)

    if args.flipTransformationGroup then
      if not rq{"flipRotateTransformationGroup"} then return false end

      local adjustedAngle
      local direction
      if math.pi / 2 < angle and angle < 3 * math.pi / 2 then
        adjustedAngle = math.pi - angle
        direction = -1
      else
        adjustedAngle = angle
        direction = 1
      end

      animator.resetTransformationGroup(args.flipRotateTransformationGroup)
      animator.resetTransformationGroup(args.flipTransformationGroup)
      animator.rotateTransformationGroup(args.flipRotateTransformationGroup, adjustedAngle)
      animator.scaleTransformationGroup(args.flipTransformationGroup, {direction, 1})
    end

    animator.resetTransformationGroup(args.transformationGroup)
    animator.rotateTransformationGroup(args.transformationGroup, angle)

  -- animator.rotateTransformationGroup("hand", adjustedAngle)
  -- animator.scaleTransformationGroup("facing", {direction, 1})

  end

  return true
end