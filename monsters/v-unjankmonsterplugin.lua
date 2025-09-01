local oldDie = die or function() end

function die()
  local board = self.deathBehavior:blackboard()
  board:setEntity("self", entity.id())
  board:setPosition("self", mcontroller.position())
  board:setNumber("dt", script.updateDt())
  board:setNumber("facingDirection", self.facingDirection or mcontroller.facingDirection())

  oldDie()
end