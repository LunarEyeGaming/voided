local oldUpdate = update or function() end

function update(dt)
  oldUpdate(dt)

  animator.resetTransformationGroup("facing")
  if mcontroller.rotation() > math.pi / 2 and mcontroller.rotation() < 3 * math.pi / 2 then
    animator.scaleTransformationGroup("facing", {1, -1})
  end
end