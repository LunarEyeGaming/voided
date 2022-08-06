require "/scripts/vec2.lua"

local oldUpdate = update or function() end

function update()
  oldUpdate()
  localAnimator.clearDrawables()
  
  self.params = animationConfig.animationParameter("animationConfig") 
  self.position = animationConfig.animationParameter("ownPosition")
  self.warningVectors = animationConfig.animationParameter("warningVectors") or {}
  for _, v in ipairs(self.warningVectors) do
    local distance, angle = v[1], v[2]
    local opacity = 1 - (distance - self.params.minRange) / (self.params.maxRange - self.params.minRange)
    local image = string.format("%s?multiply=ffffff%02x", self.params.warningImage, math.max(math.min(math.floor(opacity * 255), 255), 0))
    local drawable = {
      image = image,
      centered = true,
      rotation = angle,
      position = vec2.add(self.position, vec2.withAngle(angle, self.params.warningDistance)),
      fullbright = true
    }
    localAnimator.addDrawable(drawable)
  end
end