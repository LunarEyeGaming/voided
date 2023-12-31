local deadCollisionAction

function init()
  deadCollisionAction = config.getParameter("deadCollisionAction")
end

function update(dt)
end

function destroy()
  if mcontroller.isColliding() then
    projectile.processAction(deadCollisionAction)
  end
end