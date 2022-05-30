require "/scripts/util.lua"
require "/objects/wired/light/light.lua"

local oldInit = init
function init()
  oldInit()
  self.flickerFrequency = config.getParameter("flickerFrequency")
  self.lightColor = config.getParameter("lightColor", {255, 255, 255})
  self.timer = 0
  message.setHandler("flicker", function(_, _, intensity, duration)
    if not storage.state then return end
    animator.setAnimationState("light", "flicker")
    self.flickerIntensity = intensity
    self.flickerDuration = duration
    self.timer = duration
  end)
  
  message.setHandler("setActive", function(_, _, active)
    storage.state = active
    setLightState(active)
    self.timer = 0
  end)
end

function update(dt)
  if storage.state then
    if self.timer > 0 then
      -- The range of the sine curve is [1 - flickerIntensity, 1.0]
      -- TODO: Simplify this expression
      -- Also, not good for epilepsy! Either put up a warning or make this less flashy!
      self.timer = self.timer - dt
      local intensity = util.lerp(self.timer / self.flickerDuration, 1, 1 - self.flickerIntensity)
      local lightMagnitude = (intensity + 1 + (1 - intensity) * math.sin(2 * math.pi * self.timer * self.flickerFrequency)) / 2
      object.setLightColor({self.lightColor[1] * lightMagnitude, self.lightColor[2] * lightMagnitude, self.lightColor[3] * lightMagnitude})
    else
      animator.setAnimationState("light", "on")
      object.setLightColor(self.lightColor)
    end
  end
end