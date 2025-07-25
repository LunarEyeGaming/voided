require "/scripts/rect.lua"

vEntity = {}

---Converts a relative rectangle into a table of the bottom-left and top-right points (absolute) and returns the result.
---@param rectangle RectF
---@return [Vec2F, Vec2F]
function vEntity.getRegionPoints(rectangle)
  local absoluteRectangle = rect.translate(rectangle, entity.position())

  return {rect.ll(absoluteRectangle), rect.ur(absoluteRectangle)}
end