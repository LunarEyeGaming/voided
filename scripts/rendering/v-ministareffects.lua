require "/scripts/vec2.lua"

require "/scripts/v-animator.lua"

local oldInit = init or function() end
local oldUpdate = update or function() end

local startBurningColor
local endBurningColor
local sunRayDimColor
local sunRayBrightColor
local sunProximityRatio

local burningBlocks
local heightMap

local isActive

function init()
  oldInit()
  -- Do not run this script on planets that are not of type "v-ministar"
  if world.type() ~= "v-ministar" then
    isActive = false
    return
  end

  isActive = true

  -- Synchronizes data
  message.setHandler("v-ministareffects-updateBlocks", function(_, _, burningBlocks_, heightMap_, sunProximityRatio_)
    burningBlocks = burningBlocks_
    heightMap = heightMap_
    sunProximityRatio = sunProximityRatio_
  end)

  burningBlocks = {}
  heightMap = {list = {}}
  sunProximityRatio = 0

  startBurningColor = {255, 0, 0, 0}
  endBurningColor = {255, 119, 0, 255}
  sunRayDimColor = {255, 0, 0, 0}
  sunRayBrightColor = {255, 216, 107, 128}
end

function update(dt)
  oldUpdate(dt)  -- Drawables are implicitly cleared.

  if not isActive then return end

  -- Get position relative to player.
  local ownPos = entity.position()
  local ownVelocity = world.entityVelocity(entity.id())  --[[@as Vec2F]]
  -- Compute predicted position.
  local predictedPos = vec2.add(ownPos, vec2.mul(ownVelocity, dt))
  -- predictedPos = world.resolvePolyCollision(collisionPoly, predictedPos, 1) or predictedPos

  -- For each block in burningBlocks...
  for _, block in ipairs(burningBlocks) do
    local relativePos = vec2.sub(block.pos, predictedPos)

    -- Draw a square at that position
    localAnimator.addDrawable({
      line = {{0, 0.5}, {1, 0.5}},
      width = 8,
      position = relativePos,
      color = vAnimator.lerpColor(block.heat / block.heatTolerance, startBurningColor, endBurningColor),
      fullbright = true
    }, "ForegroundEntity-1")

    block.heat = block.heat + dt  -- Continue increasing the heat.
  end

  local sunRayColor = vAnimator.lerpColor(sunProximityRatio, sunRayBrightColor, sunRayDimColor)
  local window = world.clientWindow()

  -- For each horizontal strip in heightMap...
  for i, v in ipairs(heightMap.list) do
    local bottomY = math.max(heightMap.minHeight, window[2])
    local relativePos = vec2.sub({i + heightMap.startXPos - 1, bottomY}, predictedPos)

    -- If the value is not "completelyObstructed"...
    if v.type ~= "completelyObstructed" then
      -- Determine the y value to use (window[4] is the top of the screen)
      y = v.type == "partiallyObstructed" and v.value or window[4]

      -- Check if y is above the bottom point of the sun ray.
      if y > bottomY then
        -- Draw a line from the bottom of the screen to the collision point.
        localAnimator.addDrawable({
          line = {{0.5, 0}, {0.5, y - bottomY}},
          width = 8,
          position = relativePos,
          color = sunRayColor,
          fullbright = true
        }, "ForegroundTile-1")
      end
    end
  end
end