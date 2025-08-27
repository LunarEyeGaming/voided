require "/scripts/vec2.lua"
require "/scripts/rect.lua"

require "/scripts/v-animator.lua"
require "/scripts/v-ministarutil.lua"
require "/scripts/v-vec2.lua"

local oldInit = init or function() end
local oldUpdate = update or function() end

-- Stuff for liquid particles.
local liquidParticleDensity
local particleCullPadding
local liquidSunParticle
local liquidSunParticleLarge
local sunLiquidId

local liquidParticlePoints

-- User-configurable parameters (TODO)
local lightInterval
local useLights
local useImagesForRays
local useLiquidParticles

-- Internal parameters
local particleDensity
local startBurningColor
local endBurningColor
local sunRayDimColor
local sunRayBrightColor

-- Cached drawable info
local blockDrawable
local sunRayDrawable
local nonOceanSunRayDrawable
local sunRayDrawableFunc
local nonOceanSunRayDrawableFunc
local sunParticle

-- State variables
local ticker
local burningBlocks
local heightMap  ---@type VXMap
local rayLocationsMap ---@type VXMap
local minHeight
local lightDrawBounds
local sunProximityRatio
local sunRayColors  ---@type VXMap
local sunRayLightColors  ---@type VXMap

local isActive

function init()
  oldInit()

  ticker = VTicker:new()

  -- Initialization code to take care of liquid particles.
  v_ministarEffects_initLiquidParticles()

  -- Do not run the remainder of this script on planets that are not of type "v-ministar."
  if world.type() ~= "v-ministar" then
    isActive = false
    return
  end

  particleDensity = 0.02
  startBurningColor = {255, 0, 0, 0}
  endBurningColor = {255, 119, 0, 255}
  sunRayDimColor = {255, 0, 0, 0}
  sunRayBrightColor = {255, 216, 107, 128}

  isActive = true

  local renderConfig = player.getProperty("v-ministareffects-renderConfig", {
    lightIntervalIdx = 2,
    useLights = true,
    useImagesForRays = true,
    useLiquidParticles = true
  })
  v_ministarEffects_applyRenderConfig(renderConfig)

  message.setHandler("v-ministareffects-applyRenderConfig", function(_, _, cfg)
    v_ministarEffects_applyRenderConfig(cfg)
  end)

  -- Synchronizes data
  message.setHandler("v-ministareffects-updateBlocks", function(_, _, data)
    burningBlocks = data.heatMap
    heightMap = vMinistar.XMap:fromJson(data.heightMap)
    rayLocationsMap = vMinistar.XMap:fromJson(data.rayLocationsMap)
    sunProximityRatio = data.sunProximityRatio
    minHeight = data.minHeight
    local flareBoosts = vMinistar.XMap:fromJson(data.flareBoosts)

    -- Merge on top of existing liquid particle points, excluding particles outside of the particle cull window.
    local window = rect.pad(world.clientWindow(), particleCullPadding)
    for chunkStr, tiles in pairs(data.liquidParticlePoints) do
      local chunk = vVec2.iFromString(chunkStr)
      local chunkRect = {chunk[1] * 16, chunk[2] * 16, (chunk[1] + 1) * 16, (chunk[2] + 1) * 16}

      if tiles == "clear" then
        liquidParticlePoints[chunkStr] = nil
      elseif #tiles > 0 and rect.intersects(window, chunkRect) then
        liquidParticlePoints[chunkStr] = tiles
      end
    end

    v_ministarEffects_computeRayColors(sunProximityRatio, flareBoosts)
    v_ministarEffects_computeLightBounds()
  end)

  message.setHandler("v-ministareffects-spawnWeatherParticle", function(_, _, particle, density, minDepth, maxDepth, ignoreWind)
    vLocalAnimator.spawnOffscreenParticles(particle, {
      density = density,
      exposedOnly = true,
      pred = function(pos)
        return minDepth <= pos[2] and pos[2] <= maxDepth
      end,
      ignoreWind = ignoreWind
    })
  end)

  burningBlocks = {}
  lightDrawBounds = vMinistar.XMap:new()
  sunProximityRatio = 0

  sunParticle = {
    type = "textured",
    image = "/particles/v-ministarcloud/1.png",
    initialVelocity = {40, 0},
    approach = {2, 2},
    timeToLive = 20,
    light = {143, 99, 17},
    destructionAction = "shrink",
    destructionTime = 2,
    angularVelocity = 0,
    layer = "middle",
    collidesForeground = true,
    color = true  -- Placeholder value
  }
end

function v_ministarEffects_initLiquidParticles()
  sunLiquidId = 218
  liquidParticleDensity = 0.01
  particleCullPadding = 100

  liquidSunParticle = {
    type = "animated",
    animation = "/animations/v-solarplasma/v-solarplasma.animation",
    initialVelocity = {0, 6},
    approach = {0, 2},
    position = {0, -1},
    light = {143, 99, 17},
    timeToLive = 2,
    destructionAction = "fade",
    destructionTime = 1,
    angularVelocity = 0,
    layer = "middle",
    collidesForeground = true,
    variance = {
      initialVelocity = {4, 4}
    }
  }

  liquidSunParticleLarge = {
    type = "animated",
    animation = "/animations/v-solarplasma/v-solarplasmalarge.animation",
    initialVelocity = {0, 3},
    approach = {0, 2},
    position = {0, -1},
    light = {143, 99, 17},
    timeToLive = 4,
    destructionAction = "fade",
    destructionTime = 1,
    angularVelocity = 0,
    layer = "middle",
    collidesForeground = true,
    variance = {
      initialVelocity = {2, 2}
    }
  }

  liquidParticlePoints = {}

  ticker:addInterval(5, function()
    local window = rect.pad(world.clientWindow(), particleCullPadding)

    for chunkStr, _ in pairs(liquidParticlePoints) do
      local chunk = vVec2.iFromString(chunkStr)
      local chunkRect = {chunk[1] * 16, chunk[2] * 16, (chunk[1] + 1) * 16, (chunk[2] + 1) * 16}

      if not rect.intersects(window, chunkRect) then
        liquidParticlePoints[chunkStr] = nil
      end
    end
  end)

  -- Synchronizes liquid particle points only
  message.setHandler("v-ministareffects-updateLiquidParticles", function(_, _, liquidParticlePoints_)
    local window = rect.pad(world.clientWindow(), particleCullPadding)
    -- Merge on top of existing liquid particle points, excluding particles outside of the particle cull window.
    for chunkStr, tiles in pairs(liquidParticlePoints_) do
      local chunk = vVec2.iFromString(chunkStr)
      local chunkRect = {chunk[1] * 16, chunk[2] * 16, (chunk[1] + 1) * 16, (chunk[2] + 1) * 16}

      if tiles == "clear" then
        liquidParticlePoints[chunkStr] = nil
      elseif #tiles > 0 and rect.intersects(window, chunkRect) then
        liquidParticlePoints[chunkStr] = tiles
      end
    end
    v_ministarEffects_computeLightBounds()
  end)
end

function v_ministarEffects_applyRenderConfig(cfg)
  local lightIntervals = {8, 16, 32, 64, 128}
  lightInterval = lightIntervals[cfg.lightIntervalIdx]
  useLights = cfg.useLights
  useImagesForRays = cfg.useImagesForRays
  useLiquidParticles = cfg.useLiquidParticles
  local localAnimator_addDrawable = localAnimator.addDrawable
  local string_format = string.format
  if useImagesForRays then
    sunRayDrawable = {
      transformation = {
        {1.0, 0, 0},
        {0, 0, 0},
        {0, 0, 1.0}
      },  -- Placeholder
      image = "/scripts/rendering/v-ministarray.png",
      position = {},  -- Placeholder
      color = {},  -- Placeholder
      fullbright = true
    }
    local transformRow2 = sunRayDrawable.transformation[2]  -- Used to make changes to the y scale in the transformation
    nonOceanSunRayDrawable = {
      image = "/scripts/rendering/v-ministarray2.png",
      position = {},  -- Placeholder
      fullbright = true
    }
    local nonOceanSunRayDrawableSize = root.imageSize(nonOceanSunRayDrawable.image)
    local nonOceanSunRayDrawableImage = nonOceanSunRayDrawable.image
    blockDrawable = {  -- Construct table once. position and color will change.
      image = "/scripts/rendering/v-ministarhotspot.png",
      transformation = {
        {1, 0, 0.5},
        {0, 1, 0.5},
        {0, 0, 1}
      },
      position = {0, 0},  -- Placeholder value
      color = {0, 0, 0, 0},  -- Placeholder value
      fullbright = true
    }
    sunRayDrawableFunc = function(x, bottomY, topY, predictedPos)
      local relativePos = {x - predictedPos[1] + 0.5, (topY + bottomY) / 2 - predictedPos[2] - 0.5}

      transformRow2[2] = topY - bottomY + 1.0
      sunRayDrawable.position = relativePos
      localAnimator_addDrawable(sunRayDrawable, "Liquid-1")
    end
    nonOceanSunRayDrawableFunc = function(x, bottomY, topY, predictedPos)
      local relativePos = {x - predictedPos[1] + 0.5, (topY + bottomY) / 2 - predictedPos[2]}

      nonOceanSunRayDrawable.image = string_format("%s?crop=%d;%d;%d;%d", nonOceanSunRayDrawableImage, 0, 0, nonOceanSunRayDrawableSize[1], (topY - bottomY) * 8)

      nonOceanSunRayDrawable.position = relativePos
      localAnimator_addDrawable(nonOceanSunRayDrawable, "Liquid-1")
    end
  else
    sunRayDrawable = {
      line = {{0.5, -1}, {0.5, 0}},
      width = 8,
      position = {0, 0},  -- Placeholder
      color = {0, 0, 0, 0},  -- Placeholder
      fullbright = true
    }
    local lineEnd = sunRayDrawable.line[2]  -- Used to make changes to the top of the line used for sunRayDrawable
    blockDrawable = {
      line = {{0, 0.5}, {1, 0.5}},
      width = 8,
      position = {0, 0},  -- Placeholder value
      color = {0, 0, 0, 0},  -- Placeholder value
      fullbright = true
    }
    nonOceanSunRayDrawable = {
      line = {{0.5, -1}, {0.5, 0}},
      width = 8,
      position = {},  -- Placeholder
      color = sunRayBrightColor,
      fullbright = true
    }
    local nonOceanLineEnd = nonOceanSunRayDrawable.line[2]  -- Used to make changes to the top of the line used for nonOceanSunRayDrawable
    sunRayDrawableFunc = function(x, bottomY, topY, predictedPos)
      local relativePos = {x - predictedPos[1], bottomY - predictedPos[2]}

      lineEnd[2] = topY - bottomY
      sunRayDrawable.position = relativePos
      localAnimator_addDrawable(sunRayDrawable, "Liquid-1")
    end
    nonOceanSunRayDrawableFunc = function(x, bottomY, topY, predictedPos)
      local relativePos = {x - predictedPos[1], bottomY - predictedPos[2]}

      nonOceanLineEnd[2] = topY - bottomY
      nonOceanSunRayDrawable.position = relativePos
      localAnimator_addDrawable(nonOceanSunRayDrawable, "Liquid-1")
    end
  end
end

function update(dt)
  localAnimator.clearDrawables()
  localAnimator.clearLightSources()

  oldUpdate(dt)  -- Drawables are implicitly cleared.

  local window = world.clientWindow()
  ticker:update(dt)

  if liquidParticlePoints then
    v_ministarEffects_drawLiquidParticles(window)
  end

  -- Do nothing else if this script is not active
  if not isActive then
    return
  end

  -- Get position relative to player.
  local ownPos = entity.position()
  local ownVelocity = world.entityVelocity(entity.id())  --[[@as Vec2F]]
  -- Compute predicted position.
  local predictedPos = vec2.add(ownPos, vec2.mul(ownVelocity, dt))

  v_ministarEffects_drawBurningBlocks(predictedPos, dt, window)

  local sunRayColor = vAnimator.lerpColor(sunProximityRatio, sunRayDimColor, sunRayBrightColor)

  if heightMap then
    v_ministarEffects_drawSunRays(predictedPos, sunRayColors, window)
    v_ministarEffects_drawSunRayLights(sunRayLightColors, window)
  end
  v_ministarEffects_drawParticles(sunRayColor)
end

---Draws the burning blocks, also updating their heat.
---@param predictedPos Vec2F
---@param dt number
---@param window RectI
function v_ministarEffects_drawBurningBlocks(predictedPos, dt, window)
  local localAnimator_addDrawable = localAnimator.addDrawable
  local vAnimator_lerpColorU = vAnimator.lerpColorU

  local blockRenderLayer = "ForegroundEntity-1"
  -- For each block in burningBlocks...
  for _, block in ipairs(burningBlocks) do
    local blockPos = block.pos
    local blockPosX = blockPos[1]
    -- If the block is visible inside of the window...
    if window[1] <= blockPosX and blockPosX <= window[3] then
      -- Render it
      blockDrawable.position = {  -- Inlined vector subtraction.
        blockPosX - predictedPos[1],
        blockPos[2] - predictedPos[2]
      }
      blockDrawable.color = vAnimator_lerpColorU(block.heat / block.heatTolerance, startBurningColor, endBurningColor)
      localAnimator_addDrawable(blockDrawable, blockRenderLayer)

      block.heat = block.heat + block.heatDeltaDir * dt  -- Continue increasing the heat.
    end
  end
end

---
---@param predictedPos Vec2F
---@param rayColors VXMap
---@param window RectI
function v_ministarEffects_drawSunRays(predictedPos, rayColors, window)
  -- Get boundaries
  local startXPos, endXPos = heightMap:xbounds()

  -- Constrain startX and endX to window boundaries.
  local startX = math.max(world.nearestTo(startXPos, window[1]), startXPos)
  local endX = math.min(world.nearestTo(endXPos, window[3]), endXPos)

  local world_xwrap = world.xwrap

  -- Used for faster position-based lookups.
  local heightMap_list = heightMap.list
  local rayColors_list = rayColors.list
  local rayLocationsMap_list = rayLocationsMap.list

  local oceanCount = 0
  local nonOceanCount = 0

  -- Draw all sun rays
  for x = startX, endX do
    local xWrapped = world_xwrap(x)
    local topY = heightMap_list[xWrapped]

    if topY then
      sunRayDrawable.color = rayColors_list[xWrapped]
      if topY ~= minHeight then
        sunRayDrawableFunc(x, minHeight, topY, predictedPos)
        oceanCount = oceanCount + 1
      end

      local otherRays = rayLocationsMap_list[xWrapped]
      if otherRays then
        for _, ray in ipairs(otherRays) do
          nonOceanSunRayDrawableFunc(x, ray.s, ray.e, predictedPos)
          nonOceanCount = nonOceanCount + 1
        end
      end
    end
  end

  sb.setLogMap("v-ministareffects_raysDrawn", "%s (ocean), %s (non-ocean)", oceanCount, nonOceanCount)
end

---
---@param rayColors VXMap
---@param window RectI
function v_ministarEffects_drawSunRayLights(rayColors, window)
  if not useLights then return end

  local sunRayLightSource = {
    position = true,  -- Placeholder
    color = {0, 0, 0, 0}
  }

  local startXPos, endXPos = heightMap:xbounds()
  -- Constrain startX and endX to window boundaries.
  local startX = math.max(world.nearestTo(startXPos, window[1]), startXPos)
  local endX = math.min(world.nearestTo(endXPos, window[3]), endXPos)

  -- world.debugText("%s, %s", startX, endX, entity.position(), "green")

  -- Draw lights
  for x = startX, endX do
    local v = lightDrawBounds:get(x)
    -- if not v then
    --   sb.logInfo("--------------------------------------lightDrawBounds------------------------------------------")
    --   for x2, v2 in lightDrawBounds:values() do
    --     sb.logInfo("%s: %s", x2, v2)
    --   end
    -- end
    -- world.debugText("%s, %s", v.s, v.e, {x, v.e + x % 5}, "white")
    if v.s ~= v.e then
      local inc
      if v.s < v.e then
        inc = lightInterval
      else
        inc = -lightInterval
      end
      -- local rayRatio = math.min(1.0, ratio + boosts[i])
      -- local rayRatio = ratio + boosts[i]
      sunRayLightSource.color = rayColors:get(x)
      for y = v.s, v.e, inc do
        sunRayLightSource.position = {x, y}
        localAnimator.addLightSource(sunRayLightSource)
        -- world.debugPoint({x, y}, "white")
      end
      sunRayLightSource.position = {x, v.e}
      localAnimator.addLightSource(sunRayLightSource)
      -- world.debugPoint({x, v.e}, "white")
    end
  end
end

function v_ministarEffects_computeLightBounds()
  if not useLights then return end

  local heightMap_list = heightMap.list
  local world_xwrap = world.xwrap

  local window = world.clientWindow()

  local lightMinHeight = math.max(window[2], minHeight) // lightInterval * lightInterval

  local startXPos, endXPos = heightMap:xbounds()

  lightDrawBounds = vMinistar.XMap:new(startXPos, endXPos)
  local lightDrawBounds_list = lightDrawBounds.list

  -- Compute light drawing boundaries based on change in value.
  local prevTopY = heightMap.list[startXPos]  -- Default
  for x, topY in heightMap:xvalues() do
    lightDrawBounds_list[x] = {s = prevTopY, e = topY}
    -- world.debugLine({x, prevTopY}, {x, topY}, "white")
    prevTopY = topY
  end

  -- Derive a starting position based on startXPos.
  local startXPos2 = (startXPos // lightInterval + 1) * lightInterval
  -- Add periodic strips of lights
  for x = startXPos2, endXPos, lightInterval do
    local xWrapped = world_xwrap(x)
    local v = heightMap_list[xWrapped]
    if v and v >= lightMinHeight and v ~= minHeight then
      lightDrawBounds_list[xWrapped] = {s = lightMinHeight, e = v}
      -- world.debugLine({x, lightMinHeight}, {x, v}, "white")
    end
  end
end

---Computes ray colors and light ray colors for positions where `boosts` has defined values. Updates `sunRayColors` and
---`sunRayLightColors`.
---@param ratio number
---@param boosts VXMap
function v_ministarEffects_computeRayColors(ratio, boosts)
  local vAnimator_lerpColor = vAnimator.lerpColor
  local math_min = math.min
  local math_max = math.max
  local math_floor = math.floor

  local startX, endX = boosts:xbounds()
  sunRayColors = vMinistar.XMap:new(startX, endX)
  sunRayLightColors = vMinistar.XMap:new(startX, endX)

  local sunRayColors_list = sunRayColors.list
  local sunRayLightColors_list = sunRayLightColors.list

  for x, boost in boosts:xvalues() do
    local rayRatio = math_min(1.0, math_max(0.0, ratio + boost))
    local tempColor = vAnimator_lerpColor(rayRatio, sunRayDimColor, sunRayBrightColor)
    local sunRayLightColor = {
      math_floor(tempColor[1] * rayRatio),
      math_floor(tempColor[2] * rayRatio),
      math_floor(tempColor[3] * rayRatio)
    }
    sunRayLightColors_list[x] = sunRayLightColor
    sunRayColors_list[x] = vAnimator_lerpColor(ratio + boost, sunRayDimColor, sunRayBrightColor)
  end
end

function v_ministarEffects_drawParticles(color)
  if sunProximityRatio == 0 then return end

  local world_underground = world.underground

  sunParticle.color = color
  vLocalAnimator.spawnOffscreenParticles(sunParticle, {
    density = particleDensity,
    exposedOnly = true,
    pred = function(pos)
      return not world_underground(pos)
    end
  })
end

function v_ministarEffects_drawLiquidParticles(window)
  if not useLiquidParticles then return end
  -- for x = window[1], window[3] do
  --   local y = heightMap:get(x)
  --   if y ~= minHeight and math.random() <= liquidParticleDensity then
  --     localAnimator.spawnParticle(liquidSunParticle, {x, minHeight - (math.random() * 3)})
  --   end
  -- end
  -- for _ = 1, 1 do
  -- end

  local math_random = math.random
  local localAnimator_spawnParticle = localAnimator.spawnParticle

  local count = 0

  for _, tiles in pairs(liquidParticlePoints) do
    for _, tile in ipairs(tiles) do
      -- If the tile is inside of window, then with a probability of liquidParticleDensity...
      if window[1] <= tile[1] and tile[1] <= window[3]
      and window[2] <= tile[2] and tile[2] <= window[4]
      and math_random() <= liquidParticleDensity then
        localAnimator_spawnParticle(liquidSunParticle, tile)
      end
      count = count + 1
    end
  end

  sb.setLogMap("v-ministareffects_exposedSunCount", "%s", count)

  local pos = rect.randomPoint(window)

  local liquid = world.liquidAt(pos)
  if liquid and liquid[1] == sunLiquidId then
    localAnimator_spawnParticle(liquidSunParticleLarge, pos)
  end
end