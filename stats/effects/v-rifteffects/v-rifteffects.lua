require "/scripts/rect.lua"
require "/scripts/vec2.lua"
require "/scripts/statuseffects/v-tickdamage.lua"

local nonPlayerMovementModifiers
local newGravityMultiplier

function init()
  nonPlayerMovementModifiers = config.getParameter("nonPlayerMovementModifiers", {})

  setGravityMultiplier()
end

function setGravityMultiplier()
  local gravityModifier = config.getParameter("gravityModifier")
  local movementParams = mcontroller.baseParameters()
  local oldGravityMultiplier = movementParams.gravityMultiplier or 1

  newGravityMultiplier = gravityModifier * oldGravityMultiplier
end

function update(dt)
  mcontroller.controlParameters({
     gravityMultiplier = newGravityMultiplier
  })

  if entity.entityType() ~= "player" then
    mcontroller.controlModifiers(nonPlayerMovementModifiers)
  end

  -- local pos = mcontroller.position()
  -- local newOffset = rect.randomPoint(destabilizeOffsetRegion)
  -- mcontroller.setPosition(vec2.add(vec2.sub(pos, prevOffset), newOffset))
  -- prevOffset = newOffset
end

function uninit()

end
