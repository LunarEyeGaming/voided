require "/scripts/voidedutil.lua"

local startColor
local endColor
local endPoisonAmount

function init()
  -- startColor and endColor are RBGA color tables.
  startColor = config.getParameter("startColor")
  endColor = config.getParameter("endColor")
  
  -- The poison amount to which the endColor must correspond. startColor corresponds to a poison amount of 0.
  endPoisonAmount = config.getParameter("endPoisonAmount")
end

function update(dt)
  local poisonAmount = status.resource("v-depthPoison")
  
  local ratio = math.min(1.0, poisonAmount / endPoisonAmount)
  local color = lerpColor(ratio, startColor, endColor)
  
  setFadeColor(color)
end

-- Sets the fade directive to use the provided color. The RGB channels are used as normal, but the A channel is used to
-- set the fade amount.
function setFadeColor(color)
  local fadeColor = {color[1], color[2], color[3]}
  local fadeAmount = color[4] / 255
  effect.setParentDirectives(string.format("fade=%s=%s", stringOfColor(fadeColor), fadeAmount))
end