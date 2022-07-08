require "/scripts/vec2.lua"

local dt

function init()
  self.ttl = animationConfig.animationParameter("ttl")
  self.animationConfig = animationConfig.animationParameter("animationConfig")
  self.startColor = self.animationConfig.startColor
  self.endColor = self.animationConfig.endColor

  self.blocks = {}
  
  dt = script.updateDt()
end

function update()
  localAnimator.clearDrawables()

  local center = entity.position()

  local nextBlocks = animationConfig.animationParameter("nextBlocks")

  if nextBlocks then
    table.insert(self.blocks, {self.ttl, nextBlocks})
  end

  local i = 1
  while i <= #self.blocks do
    local blockSet = self.blocks[i]
    if blockSet[1] <= 0 then
      table.remove(self.blocks, i)
    else
      local color = lerpColor(blockSet[1] / self.ttl, self.endColor, self.startColor)
      for _, block in ipairs(blockSet[2]) do
        localAnimator.addDrawable({
          line = {{-0.5, 0}, {0.5, 0}},
          position = vec2.add(center, block),
          color = color, 
          width = 8,
          fullbright = true
        }, "ForegroundEntity+10")
      end
      blockSet[1] = blockSet[1] - dt
      i = i + 1
    end
  end
end

function lerpColor(ratio, colorA, colorB)
  -- Return the linear interpolation of colorA and colorB with ratio, capped between 0 and 255 and in integer form.
  return {
    math.floor(math.max(math.min(colorA[1] + (colorB[1] - colorA[1]) * ratio, 255), 0)),
    math.floor(math.max(math.min(colorA[2] + (colorB[2] - colorA[2]) * ratio, 255), 0)),
    math.floor(math.max(math.min(colorA[3] + (colorB[3] - colorA[3]) * ratio, 255), 0)),
    math.floor(math.max(math.min(colorA[4] + (colorB[4] - colorA[4]) * ratio, 255), 0))
  }
end