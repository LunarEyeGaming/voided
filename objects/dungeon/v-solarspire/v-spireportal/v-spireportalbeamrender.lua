require "/scripts/vec2.lua"

local oldInit = init or function() end
local oldUpdate = update or function() end

function init()
  oldInit()
end

function update()
  localAnimator.clearDrawables()

  oldUpdate()

  local beam = animationConfig.animationParameter("sunBeam")
  -- local mags = beam.mags or {}
  -- local angles = beam.angles
  -- local startPositions = beam.startPositions
  local polies = beam.polies or {}
  local startPosition = beam.startPosition
  local color = beam.color

  for i, poly in ipairs(polies) do
    localAnimator.addDrawable({
      poly = poly,
      position = startPosition,
      color = color,
      fullbright = true
    })
  end

  if #polies > 0 then
    drawBeam(beam.bottomImage, color, beam.bottomPos, beam.bottomMag, beam.bottomAngle)
    drawBeam(beam.topImage, color, beam.topPos, beam.topMag, beam.topAngle)
  end

  -- for i, mag in ipairs(mags) do
  --   local image
  --   if i == 1 then
  --     image = beam.bottomImage
  --   elseif i == #mags then
  --     image = beam.topImage
  --   else
  --     image = beam.middleImage
  --   end
  --   local pos = startPositions[i]
  --   local angle = angles[i]

  --   localAnimator.addDrawable({
  --     image = image,
  --     position = pos,
  --     color = color,
  --     fullbright = true,
  --     centered = false,
  --     transformation = matMultiply(matMultiply({
  --       {math.cos(angle), -math.sin(angle), 0},
  --       {math.sin(angle), math.cos(angle), 0},
  --       {0, 0, 1}
  --     }, {
  --       {mag + 0.5, 0, 0},
  --       {0, 1, 0},
  --       {0, 0, 1}
  --     }), {
  --       {1, 0, 0},
  --       {0, 1, -0.5},
  --       {0, 0, 1}
  --     })
  --   })
  -- end
end

function drawBeam(image, color, pos, mag, angle)
  localAnimator.addDrawable({
    image = image,
    position = pos,
    color = color,
    fullbright = true,
    centered = false,
    transformation = matMultiply(matMultiply({
      {math.cos(angle), -math.sin(angle), 0},
      {math.sin(angle), math.cos(angle), 0},
      {0, 0, 1}
    }, {
      {mag + 0.5, 0, 0},
      {0, 1, 0},
      {0, 0, 1}
    }), {
      {1, 0, 0},
      {0, 1, -0.5},
      {0, 0, 1}
    })
  })
end

function matMultiply(m1, m2)
  return {
    {m1[1][1] * m2[1][1] + m1[1][2] * m2[2][1] + m1[1][3] * m2[3][1],
     m1[1][1] * m2[1][2] + m1[1][2] * m2[2][2] + m1[1][3] * m2[3][2],
     m1[1][1] * m2[1][3] + m1[1][2] * m2[2][3] + m1[1][3] * m2[3][3]},
    {m1[2][1] * m2[1][1] + m1[2][2] * m2[2][1] + m1[2][3] * m2[3][1],
     m1[2][1] * m2[1][2] + m1[2][2] * m2[2][2] + m1[2][3] * m2[3][2],
     m1[2][1] * m2[1][3] + m1[2][2] * m2[2][3] + m1[2][3] * m2[3][3]},
    {m1[3][1] * m2[1][1] + m1[3][2] * m2[2][1] + m1[3][3] * m2[3][1],
     m1[3][1] * m2[1][2] + m1[3][2] * m2[2][2] + m1[3][3] * m2[3][2],
     m1[3][1] * m2[1][3] + m1[3][2] * m2[2][3] + m1[3][3] * m2[3][3]}
  }
end