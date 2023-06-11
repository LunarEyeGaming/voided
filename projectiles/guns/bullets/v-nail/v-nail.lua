function init()
  self.deadCollisionAction = config.getParameter("deadCollisionAction")
end

function update(dt)
end

function destroy()
  if mcontroller.isColliding() then
    projectile.processAction(self.deadCollisionAction)
  end
end