require "/scripts/vec2.lua"
require "/scripts/rect.lua"

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
  localAnimator.clearDrawables()
  localAnimator.clearLightSources()

  oldUpdate(dt)  -- Drawables are implicitly cleared.

  if not isActive then return end  -- Do nothing if this script is not active

  -- if sunProximityRatio <= 0 then return end  -- Also do nothing if sunProximityRatio is 0 (no light)

  -- Get position relative to player.
  local ownPos = entity.position()
  local ownVelocity = world.entityVelocity(entity.id())  --[[@as Vec2F]]
  -- Compute predicted position.
  local predictedPos = vec2.add(ownPos, vec2.mul(ownVelocity, dt))
  -- predictedPos = world.resolvePolyCollision(collisionPoly, predictedPos, 1) or predictedPos

  drawBurningBlocks(predictedPos, dt)

  local sunRayColor = vAnimator.lerpColor(sunProximityRatio, sunRayDimColor, sunRayBrightColor)
  -- local sunRayLightColor = {
  --   math.floor(sunRayColor[1] * sunProximityRatio),
  --   math.floor(sunRayColor[2] * sunProximityRatio),
  --   math.floor(sunRayColor[3] * sunProximityRatio)
  -- }
  local window = world.clientWindow()

  -- local entityPosMap = queryEntities(rect.pad(window, vAnimator.WINDOW_PADDING))

  -- For each horizontal strip in heightMap...
  local prevV
  for i, v in ipairs(heightMap.list) do
    local x = i + heightMap.startXPos - 1
    local bottomY = math.max(heightMap.minHeight, window[2])
    local relativePos = vec2.sub({x, bottomY}, predictedPos)

    -- If the value is not "completelyObstructed"...
    if v.type ~= "completelyObstructed" then
      -- Determine the y value to use (window[4] is the top of the screen)
      y = v.type == "partiallyObstructed" and math.min(v.value, window[4]) or window[4]

      -- Check if y is above the bottom point of the sun ray.
      if y > bottomY then
        -- Draw a line from the bottom of the screen to y.
        localAnimator.addDrawable({
          line = {{0.5, 0}, {0.5, y - bottomY}},
          width = 8,
          position = relativePos,
          color = sunRayColor,
          fullbright = true
        }, "ForegroundTile-1")
      end

      -- -- Add light source at topmost y value. Adding a light source at the bottom is unnecessary as the liquid already
      -- -- provides a light source.
      -- localAnimator.addLightSource({
      --   position = {x, y},
      --   color = sunRayLightColor
      -- })

      -- local idx = x - entityPosMap.startXPos
      -- -- If there are entities at the current strip...
      -- if entityPosMap.map[idx] then
      --   -- Add light sources for each position in entityPosMap where the y component is below `y`.
      --   for _, entityY in ipairs(entityPosMap.map[idx]) do
      --     if entityY < y then
      --       localAnimator.addLightSource({
      --         position = {x, entityY},
      --         color = sunRayLightColor
      --       })
      --     end
      --   end
      -- end
    -- -- Otherwise, if the previous value is defined and is not completely obstructed...
    -- elseif prevV and prevV.type ~= "completelyObstructed" then
    --   -- Determine the topmost y value to use (window[4] is the top of the screen)
    --   topY = prevV.type == "partiallyObstructed" and prevV.value or window[4]

    --   local direction
    --   if bottomY <= topY then
    --     direction = 1
    --   else
    --     direction = -1
    --   end
    --   -- Add light sources across the strip.
    --   for y = bottomY, topY, direction do
    --     localAnimator.addLightSource({
    --       position = {i + heightMap.startXPos - 2, y},
    --       color = sunRayLightColor
    --     })
    --   end
    end

    prevV = v
  end
end

---Draws the burning blocks, also updating their heat.
---@param predictedPos Vec2F
---@param dt number
function drawBurningBlocks(predictedPos, dt)
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
end

---Queries entities inside of `window`, returning the positions of each entity as a map from integral horizontal
---positions to a list of vertical positions.
---@param window RectI
---@return {startXPos: integer, map: table<integer, number[]>}
function queryEntities(window)
  local positionMap = {startXPos = window[1], map = {}}
  local queried = world.entityQuery({window[1], window[2]}, {window[3], window[4]}, {includedTypes = {"mobile",
  "object"}})

  for _, entityId in ipairs(queried) do
    local entityPos = world.entityPosition(entityId)

    local idx = math.floor(entityPos[1]) - window[1]

    -- Create list if not defined.
    if not positionMap[idx] then
      positionMap[idx] = {}
    end
    table.insert(positionMap[idx], entityPos[2])
  end

  return positionMap
end