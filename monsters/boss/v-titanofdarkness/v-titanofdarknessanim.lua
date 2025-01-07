require "/scripts/vec2.lua"
--[[
  A localAnimator script that adds a "blurring" effect by rendering `count` translucent copies of everything rendered by
  the current monster. These copies are placed in a radial formation at a radial offset of `radius` blocks and revolve
  around the center of the monster at a rate of `rotationRate` revolutions per second.
]]

local radius
local count
local rotationRate
local timer

local dt

function init()
  radius = 1
  count = 4
  rotationRate = 1 / 4
  timer = 0
  dt = script.updateDt()
end

function update()
  localAnimator.clearDrawables()

  local portrait = world.entityPortrait(entity.id(), "full")

  local pos = entity.position()

  for i = 1, count do
    local angleOffset = 2 * math.pi * i / count
    local startPos = vec2.add(pos, vec2.withAngle(angleOffset + rotationRate * timer * 2 * math.pi, radius))

    for _, part in ipairs(portrait) do
      -- sb.logInfo("%s", part)
      local transformation = {
        {part.transformation[1][1], part.transformation[1][2], part.transformation[1][3] * 0.125},
        {part.transformation[2][1], part.transformation[2][2], part.transformation[2][3] * 0.125},
        {part.transformation[3][1], part.transformation[3][2], part.transformation[3][3]}
      }
      localAnimator.addDrawable({
        image = part.image,
        position = vec2.add(startPos, vec2.mul(part.position, 0.125)),
        fullbright = part.fullbright,
        transformation = transformation,
        color = {part.color[1], part.color[2], part.color[3], 128},
        centered = false
      })
    end
  end
  timer = timer + dt

  -- local pos = entity.position()

  -- for i = 1, count do
  --   local angleOffset = 2 * math.pi * i / count
  --   localAnimator.addDrawable({
  --     image = "/monsters/boss/v-titanofdarkness/body.png",
  --     centered = true,
  --     position = vec2.add(pos, vec2.withAngle(angleOffset + rotationRate * timer * 2 * math.pi, radius)),
  --     color = {255, 255, 255, 128}
  --   })
  -- end
  -- timer = timer + dt
end