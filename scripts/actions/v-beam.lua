require "/scripts/util.lua"
require "/scripts/vec2.lua"

require "/scripts/v-animator.lua"
require "/scripts/v-behavior.lua"

local oldUpdate = update or function() end

local chains = {}

function update(dt)
  oldUpdate(dt)

  monster.setAnimationParameter("chains", chains)

  chains = {}
end

-- param beamType
-- param startPosition
-- param endPosition
-- param frameCount
-- param duration
function v_playBeamAnimation(args, board, _, dt)
  if not vBehavior.requireArgs("v_playBeamAnimation", args, {"beamType", "startPosition", "endPosition"}) then
    return false
  end

  local timer = 0

  local beams = config.getParameter("beams")

  local beam = beams[args.beamType]

  if not beam then
    error("Beam with type '" .. args.beamType .. "' not defined")
  end

  while timer < beam.cycle do
    local newChain = copy(beam)

    local frame = vAnimator.frameNumber(timer, beam.cycle, 0, beam.frames)

    newChain.startSegmentImage = util.replaceTag(newChain.startSegmentImage, "frame", frame)
    newChain.segmentImage = util.replaceTag(newChain.segmentImage, "frame", frame)
    newChain.endSegmentImage = util.replaceTag(newChain.endSegmentImage, "frame", frame)
    newChain.startPosition = args.startPosition
    newChain.endPosition = args.endPosition

    table.insert(chains, newChain)

    timer = timer + dt
    coroutine.yield()
  end

  return true
end

-- param maxLength
-- param direction
-- param angle
-- param startPosition
-- param collisionKinds
-- output beamEnd
-- output beamLength
function v_beamCollision(args, board)
  local rq = vBehavior.requireArgsGen("v_beamCollision", args)

  if not rq{"maxLength", "startPosition"} then return false end

  if not args.direction and not args.angle then
    sb.logWarn("v_beamCollision: must define 'direction' or 'angle'.")
    return false
  end

  local direction = args.direction and vec2.norm(args.direction) or vec2.withAngle(args.angle)
  local beamEnd = vec2.add(args.startPosition, vec2.mul(direction, args.maxLength))
  local collidePoint = world.lineCollision(args.startPosition, beamEnd, args.collisionKinds)

  if collidePoint then
    beamEnd = collidePoint
  end

  local beamLength = world.magnitude(beamEnd, args.startPosition)

  return true, {beamEnd = beamEnd, beamLength = beamLength}
end