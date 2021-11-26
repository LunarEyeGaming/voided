local oldInit = init

function init()
  oldInit()
  monster.setAnimationParameter("beams", config.getParameter("beams"))
end