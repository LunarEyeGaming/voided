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
-- param particleSpeedThreshold
-- param particleEmitter
-- param transformationGroup
-- param stateType
function v_speedEffect(args)
  local rq = vBehavior.requireArgsGen("v_speedEffect", args)
  if not rq{"stateType", "speedThreshold"} then return false end

  local velocity = mcontroller.velocity()
  local speed = vec2.mag(velocity)

  if args.particleSpeedThreshold then
    if not rq{"particleEmitter"} then return false end

    animator.setParticleEmitterActive(args.particleEmitter, speed > args.particleSpeedThreshold)
  end

  animator.setAnimationState(args.stateType, speed > args.speedThreshold and "on" or "off")

  if args.transformationGroup then
    animator.resetTransformationGroup(args.transformationGroup)
    animator.rotateTransformationGroup(args.transformationGroup, vec2.angle(velocity))
  end

  return true
end