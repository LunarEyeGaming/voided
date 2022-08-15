require "/scripts/vec2.lua"
require "/scripts/rect.lua"
require "/scripts/util.lua"

local oldUpdate = update or function() end

local params
local position
local warningVectors

function update()
  oldUpdate()
  localAnimator.clearDrawables()
  
  params = animationConfig.animationParameter("animationConfig") 
  position = animationConfig.animationParameter("ownPosition")
  warningVectors = animationConfig.animationParameter("warningVectors") or {}
  for _, v in ipairs(warningVectors) do
    local distance, angle = v[1], v[2]
    local opacity = 1 - (distance - params.minRange) / (params.maxRange - params.minRange)
    local image = string.format("%s?multiply=ffffff%02x", params.warningImage, math.max(math.min(math.floor(opacity * 255), 255), 0))
    local drawable = {
      image = image,
      centered = true,
      rotation = angle,
      position = vec2.add(position, vec2.withAngle(angle, params.warningDistance)),
      fullbright = true
    }
    local drawable2 = copy(drawable)
    drawable2.position = vec2.add(drawable2.position, rect.randomPoint({-0.25, -0.25, 0.25, 0.25}))
    drawable2.image = string.format("%s?setcolor=4a4ab5?multiply=ffffff%02x", params.warningImage, math.max(math.min(math.floor(opacity * 255), 255), 0))
    localAnimator.addDrawable(drawable2)
    localAnimator.addDrawable(drawable)
  end
end