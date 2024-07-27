require "/scripts/vec2.lua"
require "/scripts/set.lua"

-- Script for a telegraph that shrinks with the region inside of the centipede.

local shouldDieVar

function init()
  script.setUpdateDelta(1)

  shouldDieVar = false

  message.setHandler("despawn", function()
    shouldDieVar = true
  end)

  monster.setDamageBar("None")

  -- Pass params to animation script
  for _, param in ipairs({"ellipseNumPoints", "ellipseFillColor", "ellipseOutlineColor", "ellipseOutlineThickness"}) do
    passParamToAnim(param)
  end

  message.setHandler("setTelegraphConfig", function(_, _, center, radius)
    monster.setAnimationParameter("telegraphRegionConfig", {center = center, radius = radius})
  end)
end

function shouldDie()
  return shouldDieVar
end

function update(dt)
end

function passParamToAnim(param, default)
  monster.setAnimationParameter(param, config.getParameter(param, default))
end