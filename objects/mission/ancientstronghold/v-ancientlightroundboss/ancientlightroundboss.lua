require "/scripts/util.lua"
require "/objects/wired/light/light.lua"

local oldInit = init or function() end
local oldUpdate = update or function() end

local flickerFrequency
local lightColor
local timer
local flickerIntensity
local flickerDuration

function init()
  oldInit()
  flickerFrequency = config.getParameter("flickerFrequency")
  lightColor = config.getParameter("lightColor", {255, 255, 255})
  timer = 0
  message.setHandler("flicker", function(_, _, intensity, duration)
    if not storage.state then return end
    animator.setAnimationState("light", "flicker")
    flickerIntensity = intensity
    flickerDuration = duration
    timer = duration
  end)
  
  message.setHandler("setActive", function(_, _, active)
    storage.state = active
    setLightState(active)
    timer = 0
  end)
end

function update(dt)
  oldUpdate(dt)
  if storage.state then
    if timer > 0 then
      -- The range of the sine curve is [1 - flickerIntensity, 1.0]
      -- TODO: Simplify this expression
      -- Also, not good for epilepsy! Either put up a warning or make this less flashy!
      timer = timer - dt
      local intensity = util.lerp(timer / flickerDuration, 1, 1 - flickerIntensity)
      local lightMagnitude = (intensity + 1 + (1 - intensity) * math.sin(2 * math.pi * timer * flickerFrequency)) / 2
      object.setLightColor({lightColor[1] * lightMagnitude, lightColor[2] * lightMagnitude, lightColor[3] * lightMagnitude})
    else
      animator.setAnimationState("light", "on")
      object.setLightColor(lightColor)
    end
  end
end