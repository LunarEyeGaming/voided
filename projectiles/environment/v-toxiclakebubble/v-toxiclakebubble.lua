local actionOnExitLiquid

function init()
  actionOnExitLiquid = config.getParameter("actionOnExitLiquid")
end

function update(dt)
  if not world.liquidAt(mcontroller.position()) then
    projectile.die()
  end
end

function destroy()
  if not world.liquidAt(mcontroller.position()) then
    projectile.processAction(actionOnExitLiquid)
  end
end