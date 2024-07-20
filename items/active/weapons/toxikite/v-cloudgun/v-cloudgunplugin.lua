local oldInit = init or function() end

function init()
  oldInit()

  self.weapon:addTransformationGroup("swoosh", {0,0}, 0)
end