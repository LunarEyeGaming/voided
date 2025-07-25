require "/scripts/vec2.lua"
require "/scripts/v-animator.lua"

-- Modified version of /items/active/effects/lightning.lua b/c it hardcodes the render layer.

local dt
local ttl
local boltGroups
local gatherTicks = 3
local gatherTickTimer

function init()
  ttl = animationConfig.animationParameter("ttl")
  boltGroups = {}
  gatherTickTimer = gatherTicks
end

function drawLightning(startLine, endLine, displacement, minDisplacement, forks, forkAngleRange, width, color)
  if displacement < minDisplacement then
    -- Removed vec2 calls.
    localAnimator.addDrawable({
      line = {{0, 0}, {endLine[1] - startLine[1], endLine[2] - startLine[2]}},
      width = width,
      color = color,
      position = startLine,
      fullbright = true
    }, "ForegroundOverlay+10")
  else
    -- Combined the calculations for the midpoint into one expression to reduce table allocations.
    local mid = {
      (startLine[1] + endLine[1]) / 2 + randomInRange(displacement),
      (startLine[2] + endLine[2]) / 2 + randomInRange(displacement)
    }
    drawLightning(startLine, mid, displacement / 2, minDisplacement, forks - 1, forkAngleRange, width, color)
    drawLightning(mid, endLine, displacement / 2, minDisplacement, forks - 1, forkAngleRange, width, color)

    if forks > 0 then
      local direction = vec2.sub(mid, startLine)
      local length = vec2.mag(direction) / 2
      local angle = math.atan(direction[2], direction[1]) + randomInRange(forkAngleRange)
      forkEnd = {math.cos(angle) * length, math.sin(angle) * length}
      drawLightning(mid, vec2.add(mid, forkEnd), displacement / 2, minDisplacement, forks - 1, forkAngleRange, width, color)
    end
  end
end

function randomInRange(range)
  return -range + math.random() * 2 * range
end

function randomOffset(range)
  return {randomInRange(range), randomInRange(range)}
end

function update()
  dt = script.updateDt()

  localAnimator.clearDrawables()

  local tickRate = animationConfig.animationParameter("lightningTickRate") or 25

  local lightningSeed = animationConfig.animationParameter("lightningSeed")
  if not lightningSeed then
    local millis = math.floor((os.time() + (os.clock() % 1)) * 1000)
    lightningSeed = math.floor(millis / tickRate)
  end
  math.randomseed(lightningSeed)

  gatherTickTimer = gatherTickTimer - 1
  if gatherTickTimer <= 0 then
    local lightningBolts = animationConfig.animationParameter("lightning")
    if lightningBolts then
      table.insert(boltGroups, {ttl = ttl, bolts = lightningBolts})
      -- for _, bolt in pairs(lightningBolts) do
      --   local startPosition = getLinePosition(bolt, "Start")
      --   local endPosition = getLinePosition(bolt, "End")
      --   endPosition = vec2.add(startPosition, world.distance(endPosition, startPosition))
      --   if bolt.endPointDisplacement then
      --     endPosition = vec2.add(endPosition, randomOffset(bolt.endPointDisplacement))
      --   end
      --   drawLightning(startPosition, endPosition, bolt.displacement, bolt.minDisplacement, bolt.forks, bolt.forkAngleRange, bolt.width, bolt.color)
      -- end
    end

    gatherTickTimer = gatherTicks
  end

  -- For each group of lightning bolts...
  for i = #boltGroups, 1, -1 do
    local group = boltGroups[i]

    if group.ttl <= 0 then
      table.remove(boltGroups, i)
    else
      for _, bolt in ipairs(group.bolts) do
        local color = vAnimator.lerpColor(group.ttl / ttl, bolt.endColor, bolt.startColor)
        local startPosition = bolt.worldStartPosition
        local endPosition = world.nearestTo(startPosition, bolt.worldEndPosition)
        -- endPosition = vec2.add(startPosition, world.distance(endPosition, startPosition))
        if bolt.endPointDisplacement then
          endPosition = vec2.add(endPosition, randomOffset(bolt.endPointDisplacement))
        end
        drawLightning(startPosition, endPosition, bolt.displacement, bolt.minDisplacement, bolt.forks, bolt.forkAngleRange, bolt.width, color)
      end

      group.ttl = group.ttl - dt
    end
  end
end
