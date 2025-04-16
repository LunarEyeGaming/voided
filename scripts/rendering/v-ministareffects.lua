require "/scripts/vec2.lua"
require "/scripts/rect.lua"

require "/scripts/v-animator.lua"

local oldInit = init or function() end
local oldUpdate = update or function() end

local particleInterval
local startBurningColor
local endBurningColor
local sunRayDimColor
local sunRayBrightColor
local sunProximityRatio

local burningBlocks
local heightMap

local isActive

local particleTimer

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

  particleInterval = 0.05
  startBurningColor = {255, 0, 0, 0}
  endBurningColor = {255, 119, 0, 255}
  sunRayDimColor = {255, 0, 0, 0}
  sunRayBrightColor = {255, 216, 107, 128}
  particleTimer = particleInterval
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

  -- For each horizontal strip in heightMap...
  for i, v in ipairs(heightMap.list) do
    local x = i + heightMap.startXPos - 1

    -- If x is within window boundaries...
    if window[1] <= x and x <= window[3] then
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
            line = {{0.5, -1}, {0.5, y - bottomY}},
            width = 8,
            position = relativePos,
            color = sunRayColor,
            fullbright = true
          }, "Liquid-1")
          -- print(5)
        end
      end
    end
  end

  v_ministarEffects_drawParticles(sunRayColor, dt)
end

---Draws the burning blocks, also updating their heat.
---@param predictedPos Vec2F
---@param dt number
---@param window RectI
function v_ministarEffects_drawBurningBlocks(predictedPos, dt, window)
  -- For each block in burningBlocks...
  for _, block in ipairs(burningBlocks) do
    -- If the block is visible inside of the window...
    if window[1] <= block.pos[1] and block.pos[1] <= window[3] then
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
end

function v_ministarEffects_drawParticles(color, dt)
  if sunProximityRatio == 0 then return end

  particleTimer = particleTimer - dt

  if particleTimer <= 0 then
    local windowRegion = world.clientWindow()

    local leftPosition = {windowRegion[1], math.random() * (windowRegion[4] - windowRegion[2]) + windowRegion[2]}
    local rightPosition = {windowRegion[3], math.random() * (windowRegion[4] - windowRegion[2]) + windowRegion[2]}

    -- Note: windLevel is zero if there is a background block.
    local leftHorizontalSpeed = world.windLevel(leftPosition)
    if leftHorizontalSpeed == 0 then
      leftHorizontalSpeed = 40
    end
    local rightHorizontalSpeed = world.windLevel(rightPosition)
    if rightHorizontalSpeed == 0 then
      rightHorizontalSpeed = 40
    end

    if not world.material(leftPosition, "background") then
      localAnimator.spawnParticle({
        type = "textured",
        image = "/particles/v-ministarcloud/1.png",
        initialVelocity = {leftHorizontalSpeed, 0},
        approach = {2, 2},
        timeToLive = 20,
        destructionAction = "fade",
        destructionTime = 2,
        angularVelocity = 0,
        layer = "middle",
        collidesForeground = true,
        color = color
      }, leftPosition)
    end

    if not world.material(rightPosition, "background") then
      localAnimator.spawnParticle({
        type = "textured",
        image = "/particles/v-ministarcloud/1.png",
        initialVelocity = {rightHorizontalSpeed, 0},
        approach = {2, 2},
        timeToLive = 20,
        destructionAction = "shrink",
        destructionTime = 2,
        angularVelocity = 0,
        layer = "middle",
        collidesForeground = true,
        color = color
      }, rightPosition)
    end

    local velocity = world.entityVelocity(entity.id())
    particleTimer = particleInterval / (math.sqrt(vec2.mag(velocity)) + 1)
  end
end