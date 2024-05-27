require "/scripts/vec2.lua"
require "/scripts/voidedutil.lua"

local dt
local animConfig
local startColor
local endColor
local fullbright
local blocks

local testVar

function init()
  script.setUpdateDelta(3)
  ttl = animationConfig.animationParameter("ttl")
  animConfig = animationConfig.animationParameter("animationConfig")
  startColor = animConfig.startColor
  endColor = animConfig.endColor
  fullbright = animConfig.fullbright

  blocks = {}
  
  dt = script.updateDt()
  
  testVar = false
  
end

function update()
  localAnimator.clearDrawables()

  local center = entity.position()

  local nextBlocks = animationConfig.animationParameter("nextBlocks")

  if nextBlocks then
    table.insert(blocks, {ttl, nextBlocks})
  end

  local i = 1
  while i <= #blocks do
    local blockSet = blocks[i]
    if blockSet[1] <= 0 then
      table.remove(blocks, i)
    else
      local color = voidedUtil.lerpColor(blockSet[1] / ttl, endColor, startColor)
      for _, block in ipairs(blockSet[2]) do
        localAnimator.addDrawable({
          line = {{-0.5, 0}, {0.5, 0}},
          position = vec2.add(center, block),
          color = color, 
          width = 8,
          fullbright = fullbright
        }, "ForegroundEntity+10")
      end
      blockSet[1] = blockSet[1] - dt
      i = i + 1
    end
  end
end