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