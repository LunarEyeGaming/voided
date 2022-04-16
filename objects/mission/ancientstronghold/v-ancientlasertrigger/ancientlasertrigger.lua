require "/scripts/vec2.lua"

function init()
  self.anchor = config.getParameter("pointerAnchor")

  self.distance = config.getParameter("distance")
  self.travelTime = config.getParameter("travelTime")
  self.pointerOffset = config.getParameter("pointerOffset")
  self.railOffset = config.getParameter("railOffset")
  self.maxLength = config.getParameter("maxLength")
  self.velocity = self.distance / self.travelTime
  self.position = 0
  animator.scaleTransformationGroup("rail", fromAnchorAbs({self.distance, 1}))
  animator.translateTransformationGroup("rail", self.railOffset)
end

function update(dt)
  local pointerOffset = vec2.add(self.pointerOffset, fromAnchor({self.position, 0}))
  
  animator.resetTransformationGroup("pointer")
  animator.translateTransformationGroup("pointer", pointerOffset)
  
  local pointerPos = vec2.add(object.position(), pointerOffset)
  local maxEndPoint = vec2.add(pointerPos, fromAnchor({0, self.maxLength}))
  local endPoint = world.lineCollision(pointerPos, maxEndPoint)
  if not endPoint then
    endPoint = maxEndPoint
  end
  local length = world.magnitude(pointerPos, endPoint)

  animator.resetTransformationGroup("laser")
  animator.scaleTransformationGroup("laser", fromAnchorAbs({1, length}))
  if self.anchor == "right" then
    animator.translateTransformationGroup("laser", {-length, 0})
  elseif self.anchor == "top" then
    animator.translateTransformationGroup("laser", {0, -length})
  end
  
  world.debugPoint(pointerPos, "blue")
  world.debugLine(pointerPos, endPoint, "red")
  
  local queried = world.entityLineQuery(pointerPos, endPoint, {withoutEntityId = entity.id(), includedTypes = {"creature"}})
  if #queried > 0 then
    object.setOutputNodeLevel(0, true)
  else
    object.setOutputNodeLevel(0, false)
  end

  self.position = self.position + self.velocity * dt
  if self.position > self.distance or self.position < 0 then
    self.velocity = -self.velocity
  end
end

function fromAnchor(pos)
  if self.anchor == "bottom" then
    return pos
  elseif self.anchor == "left" then
    return {pos[2], pos[1]}
  elseif self.anchor == "right" then
    return {-pos[2], pos[1]}
  elseif self.anchor == "top" then
    return {pos[1], -pos[2]}
  else
    error("Parameter 'pointerAnchor' not defined or invalid")
  end
end

function fromAnchor(pos)
  if self.anchor == "bottom" then
    return pos
  elseif self.anchor == "left" then
    return {pos[2], pos[1]}
  elseif self.anchor == "right" then
    return {-pos[2], pos[1]}
  elseif self.anchor == "top" then
    return {pos[1], -pos[2]}
  else
    error("Parameter 'pointerAnchor' not defined or invalid")
  end
end

function fromAnchorAbs(pos)
  if self.anchor == "bottom" or self.anchor == "top" then
    return pos
  elseif self.anchor == "left" or self.anchor == "right" then
    return {pos[2], pos[1]}
  else
    error("Parameter 'pointerAnchor' not defined or invalid")
  end
end