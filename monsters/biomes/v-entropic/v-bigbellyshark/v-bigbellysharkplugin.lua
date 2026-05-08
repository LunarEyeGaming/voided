function moveNoRotate(direction, run, noRatioLimit)
  moveDirection = {direction[1], direction[2]}
  if not noRatioLimit and self.moveRatioLimit and moveDirection[1] ~= 0 then
    -- limit movement angle
    if math.abs(moveDirection[2] / moveDirection[1]) > self.moveRatioLimit then
      moveDirection[2] = math.abs(moveDirection[1] * self.moveRatioLimit) * util.toDirection(moveDirection[2])
    end
  end

  moveDirection = vec2.norm(moveDirection)

  -- don't change direction too often
  if util.toDirection(moveDirection[1]) ~= util.toDirection(mcontroller.facingDirection()) then
    if self.directionChangeTimer > 0 then
      moveDirection[1] = -moveDirection[1]
    else
      self.directionChangeTimer = config.getParameter("directionChangeCooldown")
    end
  end

  -- move
  if run ~= false then
    mcontroller.controlFly(moveDirection)
    animator.setAnimationState("movement", "swimFast")
  else
    mcontroller.controlParameters({flySpeed = self.slowSpeed})
    mcontroller.controlFly(moveDirection)
    animator.setAnimationState("movement", "swimSlow")
  end
end