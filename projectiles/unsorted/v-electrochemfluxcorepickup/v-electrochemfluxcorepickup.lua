require "/scripts/vec2.lua"

local MAX_GROUND_DISTANCE = 100

local pickupRange
local snapRange
local snapSpeed
local snapForce
local pickupItem

local hoverDistance
local hoverPosition
local floatSpeed
local floatControlForce

local target
local spawnedItem

function init()
  pickupRange = config.getParameter("pickupRange")
  snapRange = config.getParameter("snapRange")
  snapSpeed = config.getParameter("snapSpeed")
  snapForce = config.getParameter("snapForce")
  pickupItem = config.getParameter("pickupItem")

  hoverDistance = config.getParameter("hoverDistance")
  hoverPosition = vec2.add(world.lineCollision(mcontroller.position(), vec2.add(mcontroller.position(),
      {0, -MAX_GROUND_DISTANCE})), {0, hoverDistance})
  floatSpeed = config.getParameter("speed")
  floatControlForce = config.getParameter("floatControlForce")

  mcontroller.setVelocity({0, 0})

  world.spawnProjectile(config.getParameter("shineProjectileType"), mcontroller.position(), projectile.sourceEntity(),
      {0, 0}, false, {masterEntity = entity.id()})
end

function update(dt)
  if spawnedItem then return end

  -- If no target has been found yet...
  if not target then
    findTarget()
    floatToGround()
  -- Otherwise, if the target exists...
  elseif world.entityExists(target) then
    -- Get target position and distance to target
    local targetPos = world.entityPosition(target)
    local toTarget = world.distance(targetPos, mcontroller.position())

    -- If numeric distance to target is less than pickup range...
    if vec2.mag(toTarget) <= pickupRange then
      -- Spawn the item and die.
      world.spawnItem(pickupItem, targetPos)
      projectile.die()
      spawnedItem = true
    else
      mcontroller.approachVelocity(vec2.mul(vec2.norm(toTarget), snapSpeed), snapForce)
    end
  end
end

---Sets `target` to the first queried player within `snapRange` blocks from the current position, or `nil` if no
---player is found.
function findTarget()
  local queried = world.entityQuery(mcontroller.position(), snapRange, {includedTypes = {"player"}})
  target = queried[1]
end

---Floats to the hover position for one tick.
function floatToGround()
  local toHoverPos = world.distance(hoverPosition, mcontroller.position())

  -- Float toward the hover position
  mcontroller.approachVelocity(vec2.mul(vec2.norm(toHoverPos), floatSpeed), floatControlForce)
end