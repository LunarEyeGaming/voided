require "/scripts/util.lua"
require "/scripts/vec2.lua"

local state
local cooldownTime
local maxPlacementRange

local trackedFireMode
local canPlaceCharge
local chargePlacementPoint

function init()
  state = FSM:new()
  cooldownTime = 0.4
  maxPlacementRange = 25

  state:set(states.idle)
end

function update(dt, fireMode)
  trackedFireMode = fireMode
  canPlaceCharge, chargePlacementPoint = getChargePlacementPos()

  state:update()
end

states = {}

function states.idle()
  coroutine.yield()  -- Prevent code below from running before chargePlacementPoint is defined.
  activeItem.setScriptedAnimationParameter("placementPreviewMode", "position")

  -- Show preview
  while trackedFireMode ~= "primary" do
    world.debugLine(mcontroller.position(), chargePlacementPoint, canPlaceCharge and "green" or "red")
    activeItem.setScriptedAnimationParameter("placementPos", chargePlacementPoint)

    coroutine.yield()
  end

  state:set(states.placing)
end

function states.placing()
  if canPlaceCharge then
    activeItem.setScriptedAnimationParameter("placementPreviewMode", "direction")

    local placementPos = chargePlacementPoint  -- Save placement position

    local direction
    while trackedFireMode == "primary" do
      world.debugLine(placementPos, activeItem.ownerAimPosition(), "yellow")
      direction = world.distance(activeItem.ownerAimPosition(), placementPos)

      coroutine.yield()
    end

    state:set(states.place, placementPos, direction)
  else
    -- TODO: Play sound
    -- Wait for player to let go.
    while trackedFireMode == "primary" do
      coroutine.yield()
    end

    -- Transition back to idle
    state:set(states.idle)
  end
end

function states.place(position, direction)
  world.spawnProjectile("v-directedcharge", position, entity.id(), direction, false, {})

  util.wait(cooldownTime)

  state:set(states.idle)
end

---Returns the result of a raycast in the direction of the cursor at most `maxPlacementRange` blocks away from the
---player's current position, or the end position of the attempted raycast if the result is not defined.
---
---@return boolean success whether or not the raycast was successful
---@return Vec2F position raycast result if successful, end position otherwise.
function getChargePlacementPos()
  local aimVector = vec2.norm(world.distance(activeItem.ownerAimPosition(), mcontroller.position()))
  local posEnd = vec2.add(mcontroller.position(), vec2.mul(aimVector, maxPlacementRange))
  local collidePoint = world.lineCollision(mcontroller.position(), posEnd)

  return collidePoint ~= nil, collidePoint or posEnd
end