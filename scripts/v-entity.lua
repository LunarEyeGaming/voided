require "/scripts/rect.lua"

vEntity = {}

---Converts a relative rectangle into a table of the bottom-left and top-right points (absolute) and returns the result.
---@param rectangle RectF
---@return [Vec2F, Vec2F]
function vEntity.getRegionPoints(rectangle)
  local absoluteRectangle = rect.translate(rectangle, entity.position())

  return {rect.ll(absoluteRectangle), rect.ur(absoluteRectangle)}
end

---Returns the position of the entity `dt` seconds from now based on the entity's current velocity.
---
---__Does not work with entities that are not vehicles, monsters, NPCs, or players.__
---@param dt number
---@return Vec2F
function vEntity.predictPosition(dt)
  local ownVelocity = world.entityVelocity(entity.id())
  if not ownVelocity then
    error("Cannot predict position. Entity must be a vehicle, monster, NPC, or player.")
  end
  return vec2.add(entity.position(), vec2.mul(ownVelocity, dt))
end