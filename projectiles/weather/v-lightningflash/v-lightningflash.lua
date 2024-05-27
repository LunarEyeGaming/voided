require "/scripts/vec2.lua"
require "/scripts/voidedutil.lua"

--[[
  Creates a giant light source on destruction (which consists of a grid of particles that emit the light source). The
  light source only affects air exposed to the sky (if the "inBackground" boolean is true). If inBackground is false,
  the light source will instead act as a circular point light. That is, the light will decay as distance increases, and
  the light will immediately stop where a point of collision occurs.
]]

local oldDestroy = destroy or function() end
local oldInit = init or function() end

local lightSize
local lightInterval
local lightColor
local lightFade
local lightTimeToLive
local inBackground

function init()
  oldInit()

  lightSize = config.getParameter("megaLightSize")  -- Size of the mega-light
  lightInterval = config.getParameter("megaLightInterval")  -- Gaps between each light source (x and y), in blocks
  lightColor = config.getParameter("megaLightColor")  -- The color of the light
  lightFade = config.getParameter("megaLightFade")  -- The fade value. The larger this value is, the quicker the light will fade.
  lightTimeToLive = config.getParameter("megaLightTimeToLive")  -- How long the light lasts.
  inBackground = config.getParameter("inBackground")  -- Whether or not to treat the light as something in the background
end

-- Spawns a bunch of particles to emulate a screen-wide flash of light.
function destroy()
  oldDestroy()

  local actions = {}

  for x = -lightSize, lightSize, lightInterval[1] do
    for y = -lightSize, lightSize, lightInterval[2] do
      local pos = vec2.add(mcontroller.position(), {x, y})
      local distance = vec2.mag({x, y})

      local shouldSpawnLight
      -- If inBackground is true, check if the position has no solid tiles or background tiles. Otherwise, check if
      -- the position is within a circle of radius lightSize and is within line of sight of the center.
      if inBackground then
        shouldSpawnLight = not world.pointCollision(pos) and not world.material(pos, "background")
      else
        shouldSpawnLight = distance <= lightSize and not world.lineCollision(mcontroller.position(), pos)
      end

      if shouldSpawnLight then
        local light

        if inBackground then
          light = lightColor
        else
          light = voidedUtil.lerpColorRGB(1 - distance / lightSize, {0, 0, 0}, lightColor)
        end

        table.insert(actions, {
          action = "particle",
          specification = {
            type = "ember",
            color = {0, 0, 0, 0},
            light = light,
            fade = lightFade,
            timeToLive = lightTimeToLive,
            position = {x, y},
            pointLight = not inBackground
          }
        })
      end
    end
  end
  
  -- If actions is not empty...
  if next(actions) ~= nil then
    world.spawnProjectile("v-proxyprojectile", mcontroller.position(), nil, {0, 0}, false, {actionOnReap = actions})
  end
end