require "/scripts/vec2.lua"
require "/scripts/util.lua"
require "/scripts/rect.lua"
require "/scripts/v-behavior.lua"

-- param region
-- param position
-- Succeeds if the region is full of solid tiles and fails otherwise.
function v_regionIsSolid(args, board)
  if not args.region then
    sb.logWarn("v_regionIsSolid: args.region not defined")
    return false
  end

  if not args.position then
    sb.logWarn("v_regionIsSolid: args.position not defined")
    return false
  end

  util.debugRect(rect.translate(args.region, args.position), "green")

  for x = args.region[1], args.region[3] do
    for y = args.region[2], args.region[4] do
      world.debugPoint(vec2.add({x, y}, args.position), "green")
      if not world.pointCollision(vec2.add({x, y}, args.position)) then
        return false
      end
    end

    world.debugPoint(vec2.add({x, args.region[4]}, args.position), "green")
    if not world.pointCollision(vec2.add({x, args.region[4]}, args.position)) then
      return false
    end
  end


  world.debugPoint(vec2.add({args.region[3], args.region[4]}, args.position), "green")
  if not world.pointCollision(vec2.add({args.region[3], args.region[4]}, args.position)) then
    return false
  end

  return true
end

-- param rect
-- param position
-- param offset
function v_rectCollision(args)
  local rq = vBehavior.requireArgsGen("v_rectCollision", args)

  if not rq{"rect", "position"} then return false end

  -- Add offset to position if defined. Use args.position otherwise.
  local position = args.offset and vec2.add(args.position, args.offset) or args.position

  return world.rectCollision(rect.translate(args.rect, position))
end

-- Succeeds if a proportion of blocks `threshold` in the region `testRegion` are solid. Fails otherwise
-- param position - The anchor point of the region to test.
-- param testRegion - The region to test for collisions, relative to `position`
-- param sampleStep - Number of blocks to skip before sampling another
-- param threshold - Minimum proportion of tested blocks that have collisions for this node to run
function v_solidityTest(args)
  local rq = vBehavior.requireArgsGen("v_solidityTest", args)

  if not rq{"position", "testRegion", "sampleStep", "threshold"} then return false end

  -- Calculate number of blocks to sample.
  local sampleCount = (args.testRegion[3] - args.testRegion[1]) // args.sampleStep * (args.testRegion[4] - args.testRegion[2]) // args.sampleStep
  -- Number of blocks that are solid so far.
  local solidCount = 0

  local testRegion = rect.translate(args.testRegion, args.position)

  -- Count up all of the blocks that are solid.
  for x = testRegion[1], testRegion[3], args.sampleStep do
    for y = testRegion[2], testRegion[4], args.sampleStep do
      if world.pointCollision({x, y}) then
        solidCount = solidCount + 1
      end
    end
  end

  return solidCount / sampleCount >= args.threshold
end