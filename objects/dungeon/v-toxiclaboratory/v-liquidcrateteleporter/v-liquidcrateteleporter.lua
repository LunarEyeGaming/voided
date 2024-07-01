local oldInit = init or function() end

function init()
  oldInit()

  animator.setAnimationState("trapState", storage.active and "on" or "off")
end