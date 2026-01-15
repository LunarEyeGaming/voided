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
  local mags = beam.mags or {}
  local angle = beam.angle
  local startPositions = beam.startPositions
  local color = beam.color
  local perpOffset = -#mags / 2  -- Starting offset perpendicular to the direction of the beam.

  for i, mag in ipairs(mags) do
    local image
    if i == 1 then
      image = beam.bottomImage
    elseif i == #mags then
      image = beam.topImage
    else
      image = beam.middleImage
    end
    local pos = startPositions[i]

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