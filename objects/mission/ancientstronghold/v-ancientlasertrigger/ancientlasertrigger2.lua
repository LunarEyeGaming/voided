require "/scripts/vec2.lua"

function init()
  self.anchor = config.getParameter("pointerAnchor")

  self.pointerOffset = config.getParameter("pointerOffset")
  self.maxLength = config.getParameter("maxLength")

  self.pointerPos = vec2.add(object.position(), self.pointerOffset)
  local maxEndPoint = vec2.add(self.pointerPos, fromAnchor({0, self.maxLength}))
  self.endPoint = world.lineCollision(self.pointerPos, maxEndPoint)
  if not self.endPoint then
    self.endPoint = maxEndPoint
  end
  self.length = world.magnitude(self.pointerPos, self.endPoint)

  animator.translateTransformationGroup("pointer", self.pointerOffset)
  animator.scaleTransformationGroup("laser", fromAnchorAbs({1, self.length}))
  if self.anchor == "right" then
    animator.translateTransformationGroup("laser", {-self.length, 0})
  elseif self.anchor == "top" then
    animator.translateTransformationGroup("laser", {0, -self.length})
  end
end

function update(dt)
  world.debugPoint(self.pointerPos, "blue")
  world.debugLine(self.pointerPos, self.endPoint, "red")
  
  local queried = world.entityLineQuery(self.pointerPos, self.endPoint, {withoutEntityId = entity.id(), includedTypes = {"creature"}})
  if #queried > 0 then
    object.setOutputNodeLevel(0, true)
  else
    object.setOutputNodeLevel(0, false)
  end
end

function fromAnchor(pos)
  if self.anchor == "bottom" then
    return pos
  elseif self.anchor == "left" then
    return {pos[2], pos[1]}
  elseif self.anchor == "right" then
    return {1 - pos[2], pos[1]}
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