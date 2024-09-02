local oldUpdate = update or function() end

--[[
  Yes, TerraLib has flipping functionality, but it does this through setting an animation state, which does not work
  with the way that the Mutant Eel is animated (it uses the "body" state for animations). Using this plugin makes
  working with animations easier.
]]
function update(dt)
  oldUpdate(dt)

  animator.resetTransformationGroup("facing")
  if mcontroller.rotation() > math.pi / 2 and mcontroller.rotation() < 3 * math.pi / 2 then
    animator.scaleTransformationGroup("facing", {1, -1})
  end
end