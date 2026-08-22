require "/scripts/vec2.lua"


local detectTypes
local detectRange
local approachSpeed
local approachForce
local stopForce
local initialSpeed

local actionOnActivate

local wasActivated

local setTimeToLive

local oldInit = init or function() end
local oldUpdate = update or function() end
local oldDestroy = destroy or function() end

function init()
  oldInit()

  detectTypes = config.getParameter("detectTypes")
  detectRange = config.getParameter("detectRange")
  approachSpeed = config.getParameter("approachSpeed")
  approachForce = config.getParameter("approachForce")
  stopForce = config.getParameter("stopForce")
  initialSpeed = config.getParameter("speed")

  mcontroller.setRotation(0)

  -- mcontroller.setVelocity(vec2.withAngle(math.random() * 2 * math.pi, initialSpeed))

  wasActivated = false

  message.setHandler("activate", function()
    wasActivated = true
  end)

  -- message.setHandler("freeze", function()
  --   mcontroller.setVelocity({0, 0})
  --   isFrozen = true
  -- end)

  actionOnActivate = config.getParameter("actionOnActivate")
end

function update(dt)
  oldUpdate(dt)

  if not wasActivated then
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
  elseif vec2.mag(mcontroller.velocity()) > 0 then
    mcontroller.approachVelocity({0, 0}, stopForce)
  elseif not setTimeToLive then
    projectile.setTimeToLive(1.0)
    setTimeToLive = true
  end
end

function destroy()
  oldDestroy()

  if wasActivated and actionOnActivate then
    projectile.processAction(actionOnActivate)
  end
end