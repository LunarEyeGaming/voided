require "/scripts/vec2.lua"

local detectTypes
local detectRange
local approachSpeed
local approachForce
local initialSpeed

function init()
  detectTypes = config.getParameter("detectTypes")
  detectRange = config.getParameter("detectRange")
  approachSpeed = config.getParameter("approachSpeed")
  approachForce = config.getParameter("approachForce")
  initialSpeed = config.getParameter("speed")

  mcontroller.setVelocity(vec2.withAngle(math.random() * 2 * math.pi, initialSpeed))
end

function update(dt)
  local queried = world.entityQuery(mcontroller.position(), detectRange, {
    includedTypes = detectTypes,
    order = "nearest"
  })

  if #queried > 0 then
    local target = queried[1]
    local targetPos = world.entityPosition(target)
    local toTarget = vec2.norm(world.distance(targetPos, mcontroller.position()))

    mcontroller.approachVelocity(vec2.mul(toTarget, approachSpeed), approachForce)
  end
end