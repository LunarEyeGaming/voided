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
local nonOceanSunRayDrawableSize
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
local flareBoosts

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
  message.setHandler("v-ministareffects-updateBlocks", function(_, _, burningBlocks_, heightMap_, sunProximityRatio_, minHeight_, liquidParticlePoints_, flareBoosts_, rayLocationsMap_)
    burningBlocks = burningBlocks_
    heightMap = vMinistar.XMap:fromJson(heightMap_)
    rayLocationsMap = vMinistar.XMap:fromJson(rayLocationsMap_)
    sunProximityRatio = sunProximityRatio_
    minHeight = minHeight_
    flareBoosts = vMinistar.XMap:fromJson(flareBoosts_)

    -- Merge on top of existing liquid particle points, excluding particles outside of the particle cull window.
    local window = rect.pad(world.clientWindow(), particleCullPadding)
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
  if useImagesForRays then
    sunRayDrawable = {
      transformation = {{0, 0, 0}, {0, 0, 0}, {0, 0, 0}},  -- Placeholder
      image = "/scripts/rendering/v-ministarray.png",
      position = {},  -- Placeholder
      color = {},  -- Placeholder
      fullbright = true
    }
    nonOceanSunRayDrawable = {
      image = "/scripts/rendering/v-ministarray2.png",
      position = {},  -- Placeholder
      fullbright = true
    }
    nonOceanSunRayDrawableSize = root.imageSize(nonOceanSunRayDrawable.image)
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

      sunRayDrawable.transformation = {
        {1.0, 0.0, 0.0},
        {0.0, topY - bottomY + 1.0, 0.0},
        {0.0, 0.0, 1.0}
      }
      sunRayDrawable.position = relativePos
      localAnimator.addDrawable(sunRayDrawable, "Liquid-1")
    end
    nonOceanSunRayDrawableFunc = function(x, bottomY, topY, predictedPos)
      local relativePos = {x - predictedPos[1] + 0.5, (topY + bottomY) / 2 - predictedPos[2]}

      local temp = nonOceanSunRayDrawable.image
      nonOceanSunRayDrawable.image = temp .. string.format("?crop=%d;%d;%d;%d", 0, 0, nonOceanSunRayDrawableSize[1], (topY - bottomY) * 8)

      nonOceanSunRayDrawable.position = relativePos
      localAnimator.addDrawable(nonOceanSunRayDrawable, "Liquid-1")

      nonOceanSunRayDrawable.image = temp
    end
  else
    sunRayDrawable = {
      line = {{0, 0}, {0, 0}},  -- Placeholder
      width = 8,
      position = {0, 0},  -- Placeholder
      color = {0, 0, 0, 0},  -- Placeholder
      fullbright = true
    }
    blockDrawable = {
      line = {{0, 0.5}, {1, 0.5}},
      width = 8,
      position = {0, 0},  -- Placeholder value
      color = {0, 0, 0, 0},  -- Placeholder value
      fullbright = true
    }
    nonOceanSunRayDrawable = {
      line = {{0, 0}, {0, 0}},
      width = 8,
      position = {},  -- Placeholder
      color = sunRayBrightColor,
      fullbright = true
    }
    sunRayDrawableFunc = function(x, bottomY, topY, predictedPos)
      local relativePos = {x - predictedPos[1], bottomY - predictedPos[2]}

      sunRayDrawable.line = {{0.5, -1}, {0.5, topY - bottomY}}
      sunRayDrawable.position = relativePos
      localAnimator.addDrawable(sunRayDrawable, "Liquid-1")
    end
    nonOceanSunRayDrawableFunc = function(x, bottomY, topY, predictedPos)
      local relativePos = {x - predictedPos[1], bottomY - predictedPos[2]}

      nonOceanSunRayDrawable.line = {{0.5, -1}, {0.5, topY - bottomY}}
      nonOceanSunRayDrawable.position = relativePos
      localAnimator.addDrawable(nonOceanSunRayDrawable, "Liquid-1")
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
    v_ministarEffects_drawSunRays(predictedPos, sunProximityRatio, flareBoosts, window)
    v_ministarEffects_drawSunRayLights(sunProximityRatio, flareBoosts, window)
  end
  v_ministarEffects_drawParticles(sunRayColor)
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

---
---@param predictedPos Vec2F
---@param ratio number
---@param boosts VXMap
---@param window RectI
function v_ministarEffects_drawSunRays(predictedPos, ratio, boosts, window)
  -- Get boundaries
  local startXPos, endXPos = heightMap:xbounds()

  -- Constrain startX and endX to window boundaries.
  local startX = math.max(world.nearestTo(startXPos, window[1]), startXPos)
  local endX = math.min(world.nearestTo(endXPos, window[3]), endXPos)

  -- Draw all sun rays
  for x = startX, endX do
    local topY = heightMap:get(x)

    if topY then
      sunRayDrawable.color = vAnimator.lerpColor(ratio + boosts:get(x), sunRayDimColor, sunRayBrightColor)
      if topY ~= minHeight then
        sunRayDrawableFunc(x, minHeight, topY, predictedPos)
      end

      local otherRays = rayLocationsMap:get(x)
      if otherRays then
        for _, ray in ipairs(otherRays) do
          nonOceanSunRayDrawableFunc(x, ray.s, ray.e, predictedPos)
        end
      end
    end
  end
end

---
---@param ratio number
---@param boosts VXMap
---@param window RectI
function v_ministarEffects_drawSunRayLights(ratio, boosts, window)
  if not useLights then return end

  local sunRayLightSource = {
    position = true,  -- Placeholder
    color = {0, 0, 0, 0}
  }

  local startXPos, endXPos = heightMap:xbounds()
  local startX = math.max(window[1], startXPos)
  local endX = math.min(window[3], endXPos)

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
      local rayRatio = math.min(1.0, math.max(0.0, ratio + boosts:get(x)))
      -- local sunRayColor = vAnimator.lerpColorU(rayRatio, sunRayDimColor, sunRayBrightColor)
      local sunRayColor = vAnimator.lerpColor(rayRatio, sunRayDimColor, sunRayBrightColor)
      local sunRayLightColor = {
        math.floor(sunRayColor[1] * rayRatio),
        math.floor(sunRayColor[2] * rayRatio),
        math.floor(sunRayColor[3] * rayRatio)
      }
      sunRayLightSource.color = sunRayLightColor
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

  local window = world.clientWindow()

  local lightMinHeight = math.max(window[2], minHeight) // lightInterval * lightInterval

  local startXPos, endXPos = heightMap:xbounds()

  -- Compute light drawing boundaries based on change in value.
  local prevTopY = heightMap.list[startXPos]  -- Default
  -- for i, topY in ipairs(heightMap.list) do
  --   lightDrawBounds[i] = {s = prevTopY, e = topY}
  --   prevTopY = topY
  -- end
  for x, topY in heightMap:xvalues() do
    lightDrawBounds:set(x, {s = prevTopY, e = topY})
    -- world.debugLine({x, prevTopY}, {x, topY}, "white")
    prevTopY = topY
  end

  -- Derive a starting position based on startXPos.
  local startX = (startXPos // lightInterval + 1) * lightInterval
  -- Add periodic strips of lights
  for x = startX, endXPos, lightInterval do
    local v = heightMap:get(x)
    if v and v >= lightMinHeight and v ~= minHeight then
      lightDrawBounds:set(x, {s = lightMinHeight, e = v})
      -- world.debugLine({x, lightMinHeight}, {x, v}, "white")
    end
  end
end

function v_ministarEffects_drawParticles(color)
  if sunProximityRatio == 0 then return end

  sunParticle.color = color
  vLocalAnimator.spawnOffscreenParticles(sunParticle, {
    density = particleDensity,
    exposedOnly = true,
    pred = function(pos)
      return not world.underground(pos)
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

  local count = 0

  for _, tiles in pairs(liquidParticlePoints) do
    for _, tile in ipairs(tiles) do
      if rect.contains(window, tile) and math.random() <= liquidParticleDensity then
        localAnimator.spawnParticle(liquidSunParticle, tile)
      end
      count = count + 1
    end
  end

  sb.setLogMap("v-ministareffects_exposedSunCount", "%s", count)

  local pos = rect.randomPoint(window)

  local liquid = world.liquidAt(pos)
  if liquid and liquid[1] == sunLiquidId then
    localAnimator.spawnParticle(liquidSunParticleLarge, pos)
  end
end