require "/scripts/vec2.lua"
require "/scripts/poly.lua"

local oldInit = init or function() end
local oldUpdate = update or function() end

local clingSpeed
local clingControlForce

function init()
  oldInit()

  clingSpeed = config.getParameter("clingSpeed", 50)
  clingControlForce = config.getParameter("clingControlForce", 1000)
end

function update(dt)
  oldUpdate(dt)

  updateStick()
end

function updateStick()
  -- Adjust rotation to face into the ground.
  local groundDirection = findGroundDirection(0.75)
  local headingAngle
  if groundDirection then
    world.debugLine(mcontroller.position(), vec2.add(groundDirection, mcontroller.position()), "green")
    headingAngle = vec2.angle(groundDirection)
    mcontroller.approachVelocity(vec2.withAngle(headingAngle, clingSpeed), clingControlForce)
    mcontroller.applyParameters({gravityEnabled = false})
  else
    headingAngle = vec2.angle(mcontroller.velocity())
    mcontroller.applyParameters({gravityEnabled = true})
  end
  mcontroller.setRotation(headingAngle)
end

function findGroundDirection(testDistance)
  testDistance = testDistance or 0.25

  local pointCount = 8

  -- Counter-clockwise
  local angle1
  for i = 0, pointCount - 1 do
    local angle = (i * 2 * math.pi / pointCount) - math.pi / 2
    local testPos = vec2.add(mcontroller.position(), vec2.withAngle(angle, testDistance))
    if world.polyCollision(poly.translate(mcontroller.collisionPoly(), testPos)) then
      angle1 = angle
      break
    end
  end

  -- Clockwise
  local angle2
  for i = 0, pointCount - 1 do
    local angle = -(i * 2 * math.pi / pointCount) - math.pi / 2
    local testPos = vec2.add(mcontroller.position(), vec2.withAngle(angle, testDistance))
    if world.polyCollision(poly.translate(mcontroller.collisionPoly(), testPos)) then
      angle2 = angle
      break
    end
  end

  if not (angle1 and angle2) then
    return nil
  end

  -- Since there are two possibilities, test the two angles that bisect angle1 and angle2 and see which one leads to a
  -- collision.
  local angle = (angle1 + angle2) / 2
  local testPos = vec2.add(mcontroller.position(), vec2.withAngle(angle, testDistance))
  if world.polyCollision(poly.translate(mcontroller.collisionPoly(), testPos)) then
    return vec2.withAngle(angle, 1.0)
  end

  angle = angle + math.pi
  local testPos = vec2.add(mcontroller.position(), vec2.withAngle(angle, testDistance))
  if world.polyCollision(poly.translate(mcontroller.collisionPoly(), testPos)) then
    return vec2.withAngle(angle, 1.0)
  end
end