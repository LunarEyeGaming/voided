require "/scripts/vec2.lua"

-- Modified version of /items/active/effects/lightning.lua b/c I want something more flexible.

function drawLightning(rng, startLine, endLine, displacement, minDisplacement, forks, forkAngleRange, width, color, outlineWidth, outlineColor)
  -- if displacement < minDisplacement then
  --   local position = startLine
  --   endLine = vec2.sub(endLine, startLine)
  --   startLine = {0,0}
  --   localAnimator.addDrawable({line = {startLine, endLine}, width = width + outlineWidth, color = outlineColor, position = position, fullbright = true})
  --   localAnimator.addDrawable({line = {startLine, endLine}, width = width, color = color, position = position, fullbright = true})
  -- else
  --   local mid = {(startLine[1] + endLine[1]) / 2, (startLine[2] + endLine[2]) / 2}
  --   mid = vec2.add(mid, randomOffset(rng, displacement))
  --   drawLightning(rng, startLine, mid, displacement / 2, minDisplacement, forks - 1, forkAngleRange, width, color, outlineWidth, outlineColor)
  --   drawLightning(rng, mid, endLine, displacement / 2, minDisplacement, forks - 1, forkAngleRange, width, color, outlineWidth, outlineColor)

  --   if forks > 0 then
  --     local direction = vec2.sub(mid, startLine)
  --     local length = vec2.mag(direction) / 2
  --     local angle = math.atan(direction[2], direction[1]) + randomInRange(rng, forkAngleRange)
  --     forkEnd = vec2.mul({math.cos(angle), math.sin(angle)}, length)
  --     drawLightning(rng, mid, vec2.add(mid, forkEnd), displacement / 2, minDisplacement, forks - 1, forkAngleRange, width, color, outlineWidth, outlineColor)
  --   end
  -- end
  local lines = {}
  local positions = {}
  makeLightning(rng, lines, startLine, endLine, displacement, minDisplacement, forks, forkAngleRange)

  -- Make everything relative to one position.
  for i, line in ipairs(lines) do
    positions[i] = line[1]
    line[2] = vec2.sub(line[2], line[1])
    line[1] = {0,0}
  end

  -- First pass: Outlines
  for i, line in ipairs(lines) do
    localAnimator.addDrawable({line = line, width = width + outlineWidth, color = outlineColor, position = positions[i], fullbright = true})
  end

  -- Second pass: Fill
  for i, line in ipairs(lines) do
    localAnimator.addDrawable({line = line, width = width, color = color, position = positions[i], fullbright = true})
  end
end

function makeLightning(rng, outLines, startLine, endLine, displacement, minDisplacement, forks, forkAngleRange)
  if displacement < minDisplacement then
    table.insert(outLines, {startLine, endLine})
  else
    local mid = {(startLine[1] + endLine[1]) / 2, (startLine[2] + endLine[2]) / 2}
    mid = vec2.add(mid, randomOffset(rng, displacement))
    makeLightning(rng, outLines, startLine, mid, displacement / 2, minDisplacement, forks - 1, forkAngleRange)
    makeLightning(rng, outLines, mid, endLine, displacement / 2, minDisplacement, forks - 1, forkAngleRange)

    if forks > 0 then
      local direction = vec2.sub(mid, startLine)
      local length = vec2.mag(direction) / 2
      local angle = math.atan(direction[2], direction[1]) + randomInRange(rng, forkAngleRange)
      forkEnd = vec2.mul({math.cos(angle), math.sin(angle)}, length)
      makeLightning(rng, outLines, mid, vec2.add(mid, forkEnd), displacement / 2, minDisplacement, forks - 1, forkAngleRange)
    end
  end
end

function randomInRange(rng, range)
  return -range + rng:randf() * 2 * range
end

function randomOffset(rng, range)
  return {randomInRange(rng, range), randomInRange(rng, range)}
end

function update()
  localAnimator.clearDrawables()

  local tickRate = animationConfig.animationParameter("lightningTickRate") or 25

  local lightningSeed = animationConfig.animationParameter("lightningSeed")
  if not lightningSeed then
    local millis = math.floor((os.time() + (os.clock() % 1)) * 1000)
    lightningSeed = math.floor(millis / tickRate)
  end

  local rng = sb.makeRandomSource(lightningSeed)

  local ownerPosition = function()
    if activeItemAnimation then
      return activeItemAnimation.ownerPosition()
    end
    if entity then
      return entity.position()
    end
  end

  local getLinePosition = function(bolt, positionType)
    return bolt["world"..positionType.."Position"]
      or (bolt["item"..positionType.."Position"] and vec2.add(ownerPosition(), activeItemAnimation.handPosition(bolt["item"..positionType.."Position"])))
      or (bolt["part"..positionType.."Position"] and vec2.add(ownerPosition(), animationConfig.partPoint(bolt["part"..positionType.."Position"][1], bolt["part"..positionType.."Position"][2])))
  end

  local lightningBolts = animationConfig.animationParameter("lightning")
  if lightningBolts then
    for _, bolt in pairs(lightningBolts) do
      local startPosition = getLinePosition(bolt, "Start")
      local endPosition = getLinePosition(bolt, "End")
      endPosition = vec2.add(startPosition, world.distance(endPosition, startPosition))
      if bolt.endPointDisplacement then
        endPosition = vec2.add(endPosition, randomOffset(rng, bolt.endPointDisplacement))
      end
      drawLightning(rng, startPosition, endPosition, bolt.displacement, bolt.minDisplacement, bolt.forks, bolt.forkAngleRange, bolt.width, bolt.color, bolt.outlineWidth, bolt.outlineColor)
    end
  end
end
