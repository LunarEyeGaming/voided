require "/scripts/vec2.lua"

-- Taken directly from the Swansong script.
-- predicts the direction the target will be in in `time` seconds
-- trackRange optionally gives an optimal range for the prediction
function anglePrediction(sourcePosition, targetId, time, trackRange)
    local targetVelocity = world.entityVelocity(targetId)
    local toTarget = world.distance(world.entityPosition(targetId), sourcePosition)
    
    local trackRange = trackRange or vec2.mag(toTarget)
    local perpendicular = vec2.rotate(vec2.norm(toTarget), math.pi / 2)
    local angularVel = vec2.dot(perpendicular, vec2.norm(targetVelocity)) * (vec2.mag(targetVelocity) / trackRange)
    return vec2.angle(toTarget) + angularVel * time
end

-- anglePrediction from swansong script, but returns a vector
function v_aimVectorPrediction(args, board)
  local angle = anglePrediction(args.sourcePosition, args.target, args.time, args.trackRange)
  return true, {vector = vec2.withAngle(angle)}
end