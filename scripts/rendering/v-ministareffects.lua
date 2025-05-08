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
local particleDensity
local blockDrawable

local burningBlocks
local heightMap

local isActive
local SECTOR_SIZE = 32

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

  particleInterval = 0.01
  startBurningColor = {255, 0, 0, 0}
  endBurningColor = {255, 119, 0, 255}
  sunRayDimColor = {255, 0, 0, 0}
  sunRayBrightColor = {255, 216, 107, 128}
  particleDensity = 0.02
  blockDrawable = {  -- Construct table once. position and color will change.
    line = {{0, 0.5}, {1, 0.5}},
    width = 8,
    position = {0, 0},  -- Placeholder value
    color = {0, 0, 0, 0},  -- Placeholder value
    fullbright = true
  }
end

function update(dt)
  localAnimator.clearDrawables()

  oldUpdate(dt)  -- Drawables are implicitly cleared.

  if not isActive then return end  -- Do nothing if this script is not active

  -- Get position relative to player.
  local ownPos = entity.position()
  local ownVelocity = world.entityVelocity(entity.id())  --[[@as Vec2F]]
  -- Compute predicted position.
  local predictedPos = vec2.add(ownPos, vec2.mul(ownVelocity, dt))
  -- predictedPos = world.resolvePolyCollision(collisionPoly, predictedPos, 1) or predictedPos
  local window = world.clientWindow()

  v_ministarEffects_drawBurningBlocks(predictedPos, dt, window)

  local sunRayColor = vAnimator.lerpColor(sunProximityRatio, sunRayDimColor, sunRayBrightColor)

  v_ministarEffects_drawSunRays(predictedPos, sunRayColor, window)

  v_ministarEffects_drawParticles(sunRayColor, dt)
end

---Draws the burning blocks, also updating their heat.
---@param predictedPos Vec2F
---@param dt number
---@param window RectI
function v_ministarEffects_drawBurningBlocks(predictedPos, dt, window)
  local blockRenderLayer = "ForegroundEntity-1"
  -- For each block in burningBlocks...
  for _, block in ipairs(burningBlocks) do
    -- If the block is visible inside of the window...
    if window[1] <= block.pos[1] and block.pos[1] <= window[3] then
      -- Draw a square at that position
      blockDrawable.position = vec2.sub(block.pos, predictedPos)
      blockDrawable.color = vAnimator.lerpColorU(block.heat / block.heatTolerance, startBurningColor, endBurningColor)
      localAnimator.addDrawable(blockDrawable, blockRenderLayer)

      block.heat = block.heat + block.heatDeltaDir * dt  -- Continue increasing the heat.
    end
  end
end

function v_ministarEffects_drawSunRays(predictedPos, color, window)
  local sunRayDrawable = {
    line = true,  -- Placeholder
    width = 8,
    position = true,  -- Placeholder
    color = color,
    fullbright = true
  }
  -- For each horizontal strip in heightMap...
  for i, v in ipairs(heightMap.list) do
    local x = i + heightMap.startXPos - 1

    -- If x is within window boundaries...
    if window[1] <= x and x <= window[3] then
      local topY = v.maxValue
      local bottomY = heightMap.minHeight
      local relativePos = vec2.sub({x, bottomY}, predictedPos)

      -- world.debugText("%s", topY, {x, predictedPos[2] - x % 3}, "green")
      -- world.debugText("%s", bottomY, {x, predictedPos[2] - x % 3 - 5}, "red")

      if topY ~= bottomY then
        sunRayDrawable.line = {{0.5, -1}, {0.5, topY - bottomY}}
        sunRayDrawable.position = relativePos
        localAnimator.addDrawable(sunRayDrawable, "Liquid-1")
      end
    end
  end
end

-- function v_ministarEffects_drawSunRays(predictedPos, color, window)
--   local sunRayDrawable = {
--     line = true,  -- Placeholder
--     width = 8,
--     position = true,  -- Placeholder
--     color = color,
--     fullbright = true
--   }
--   -- For each horizontal strip in heightMap...
--   for _, jsonV in ipairs(heightMap.list) do
--     local i = jsonV.i
--     local heightSectorMap = jsonV.v
--     for j, v in ipairs(heightSectorMap) do
--       local x = (i - 1) * SECTOR_SIZE + j - 1

--       -- If x is within window boundaries...
--       if window[1] <= x and x <= window[3] then
--         local topY = v.maxValue
--         local bottomY = heightMap.minHeight
--         local relativePos = vec2.sub({x, bottomY}, predictedPos)

--         -- world.debugText("%s", topY, {x, predictedPos[2] - x % 3}, "green")
--         -- world.debugText("%s", bottomY, {x, predictedPos[2] - x % 3 - 5}, "red")

--         if topY ~= bottomY then
--           sunRayDrawable.line = {{0.5, -1}, {0.5, topY - bottomY}}
--           sunRayDrawable.position = relativePos
--           localAnimator.addDrawable(sunRayDrawable, "Liquid-1")
--         end
--       end
--     end
--   end
-- end

function v_ministarEffects_drawParticles(color, dt)
  if sunProximityRatio == 0 then return end

  local windowRegion = world.clientWindow()

  for y = windowRegion[2], windowRegion[4] do
    local leftPosition = {windowRegion[1], y}

    if math.random() <= particleDensity
        and not world.material(leftPosition, "background")
        and not world.underground(leftPosition) then
      -- Note: windLevel is zero if there is a background block.
      local leftHorizontalSpeed = world.windLevel(leftPosition)

      if leftHorizontalSpeed == 0 then
        leftHorizontalSpeed = 40
      end

      localAnimator.spawnParticle({
        type = "textured",
        image = "/particles/v-ministarcloud/1.png",
        initialVelocity = {leftHorizontalSpeed, 0},
        approach = {2, 2},
        timeToLive = 20,
        light = {143, 99, 17},
        destructionAction = "fade",
        destructionTime = 2,
        angularVelocity = 0,
        layer = "middle",
        collidesForeground = true,
        color = color
      }, leftPosition)
    end

    local rightPosition = {windowRegion[3], y}

    if math.random() <= particleDensity
        and not world.material(rightPosition, "background")
        and not world.underground(rightPosition) then
      local rightHorizontalSpeed = world.windLevel(rightPosition)
      if rightHorizontalSpeed == 0 then
        rightHorizontalSpeed = 40
      end

      localAnimator.spawnParticle({
        type = "textured",
        image = "/particles/v-ministarcloud/1.png",
        initialVelocity = {rightHorizontalSpeed, 0},
        approach = {2, 2},
        timeToLive = 20,
        light = {143, 99, 17},
        destructionAction = "shrink",
        destructionTime = 2,
        angularVelocity = 0,
        layer = "middle",
        collidesForeground = true,
        color = color
      }, rightPosition)
    end
  end
end