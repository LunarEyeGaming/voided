require "/scripts/vec2.lua"

function init()
  local direction = config.getParameter("direction")
  local angle
  if direction then
    angle = vec2.angle(direction)
  else
    angle = config.getParameter("angle", 0) * math.pi / 180
  end
  angle = angle + config.getParameter("angleOffset", 0) * math.pi / 180
  animator.resetTransformationGroup("lens")
  animator.rotateTransformationGroup("lens", angle, config.getParameter("center"))
end