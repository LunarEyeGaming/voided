local oldInit = init or function() end

function init()
  oldInit()

  self.weapon:addTransformationGroup("swoosh", {0,0}, math.pi/2)
end