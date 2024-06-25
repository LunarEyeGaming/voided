require "/scripts/vec2.lua"
require "/scripts/v-animator.lua"

local dt
local animConfig
local startColor
local endColor
local fullbright
local processedBlocks

local oldBlocksId

function init()
  script.setUpdateDelta(3)
  ttl = animationConfig.animationParameter("ttl")
  animConfig = animationConfig.animationParameter("animationConfig")
  startColor = animConfig.startColor
  endColor = animConfig.endColor
  fullbright = animConfig.fullbright

  processedBlocks = {}
  
  dt = script.updateDt()
  
  oldBlocksId = -1
end

function update()
  localAnimator.clearDrawables()

  local center = entity.position()

  local blocks = animationConfig.animationParameter("blocks")
  local blocksId = animationConfig.animationParameter("blocksId")

  if blocksId ~= oldBlocksId and blocks then
    -- Used twice so that we know the original time to live
    for _, block in ipairs(blocks) do
      table.insert(processedBlocks, {block.ttl or ttl, block.ttl or ttl, block.block})
    end
  end

  local i = 1
  while i <= #processedBlocks do
    local block = processedBlocks[i]
    if block[1] <= 0 then
      table.remove(processedBlocks, i)
    else
      local color = vAnimator.lerpColor(block[1] / block[2], endColor, startColor)
      localAnimator.addDrawable({
        line = {{-0.5, 0}, {0.5, 0}},
        position = vec2.add(center, block[3]),
        color = color, 
        width = 8,
        fullbright = fullbright
      }, "ForegroundEntity+10")
      block[1] = block[1] - dt
      i = i + 1
    end
  end
  
  oldBlocksId = blocksId
end