require "/scripts/voidedutil.lua"

local pulseOpacity
local pulseDarkColor
local pulseBrightColor
local halfPulsePeriod

local pulseTimer

function init()
  pulseOpacity = config.getParameter("pulseOpacity")
  pulseDarkColor = config.getParameter("pulseDarkColor")
  pulseBrightColor = config.getParameter("pulseBrightColor")
  halfPulsePeriod = config.getParameter("pulsePeriod") / 2

  pulseTimer = 0
  
  effect.addStatModifierGroup({{stat = "invulnerable", amount = 1}})
end

function update(dt)
  pulseTimer = pulseTimer + dt
  
  if pulseTimer < halfPulsePeriod then
    updatePulseColor(lerpColorRGB(pulseTimer / halfPulsePeriod, pulseDarkColor, pulseBrightColor))
  elseif pulseTimer < halfPulsePeriod * 2 then
    updatePulseColor(lerpColorRGB(2 - pulseTimer / halfPulsePeriod, pulseDarkColor, pulseBrightColor))
  else
    pulseTimer = 0
    updatePulseColor(pulseDarkColor)
  end
end

function updatePulseColor(color)
  effect.setParentDirectives(string.format("fade=%02x%02x%02x=%s", color[1], color[2], color[3], pulseOpacity))
end
