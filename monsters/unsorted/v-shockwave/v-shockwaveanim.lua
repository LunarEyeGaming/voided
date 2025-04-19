require "/scripts/vec2.lua"
require "/scripts/v-animator.lua"

local oldInit = init or function() end
local oldUpdate = update or function() end

local dt
local ttl
local animConfig
local startColor
local endColor
local fullbright
local blocks
local gatherTicks = 3
local gatherTickTimer

function init()
  oldInit()

  -- script.setUpdateDelta(3)
  ttl = animationConfig.animationParameter("ttl")
  animConfig = animationConfig.animationParameter("animationConfig")
  startColor = animConfig.startColor
  endColor = animConfig.endColor
  fullbright = animConfig.fullbright

  blocks = {}

  dt = script.updateDt()

  gatherTickTimer = gatherTicks
end

function update()
  localAnimator.clearDrawables()

  oldUpdate()

  local center = entity.position()

  gatherTickTimer = gatherTickTimer - 1
  if gatherTickTimer <= 0 then
    local nextBlocks = animationConfig.animationParameter("nextBlocks")

    if nextBlocks then
      table.insert(blocks, {ttl, nextBlocks})
    end

    local particleNextBlocks = animationConfig.animationParameter("particleNextBlocks")

    -- Spawn particles
    if particleNextBlocks then
      for _, block in ipairs(particleNextBlocks) do
        localAnimator.spawnParticle(animConfig.damageIndicatorParticle, vec2.add(entity.position(), block))
      end
    end

    gatherTickTimer = gatherTicks
  end

  local i = 1
  while i <= #blocks do
    local blockSet = blocks[i]
    if blockSet[1] <= 0 then
      table.remove(blocks, i)
    else
      local color = vAnimator.lerpColor(blockSet[1] / ttl, endColor, startColor)
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