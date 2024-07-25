local oldInit = init or function() end

function init()
  oldInit()

  message.setHandler("setPhase", function(_, _, phase)
    animator.setGlobalTag("phase", phase)
  end)
end

function getChildren()
  return {}
end

function getTail()
  return entity.id()
end

function trailAlongEllipse()
  -- Do nothing
end