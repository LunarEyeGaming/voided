require "/scripts/vec2.lua"
require "/scripts/rect.lua"

require "/scripts/v-animator.lua"
require "/scripts/v-ministarutil.lua"
require "/scripts/v-vec2.lua"

local oldInit = init or function() end
local oldUpdate = update or function() end

-- Stuff for liquid particles.
local liquidParticleDensity
local liquidSunParticle
local liquidSunParticleLarge
local sunLiquidId

local liquidParticlePoints

-- User-configurable parameters (TODO)
local lightInterval
local useLights
local useImagesForRays

-- Internal parameters
local particleDensity
local startBurningColor
local endBurningColor
local sunRayDimColor
local sunRayBrightColor

-- Cached drawable tables
local blockDrawable
local sunRayDrawable
local sunRayDrawableFunc
local sunParticle

-- State variables
local ticker
local burningBlocks
local heightMap
local minHeight
local lightDrawBounds
local sunProximityRatio

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

  isActive = true

  local renderConfig = player.getProperty("v-ministareffects-renderConfig", {
    lightIntervalIdx = 2,
    useLights = true,
    useImagesForRays = true
  })
  v_ministarEffects_applyRenderConfig(renderConfig)

  message.setHandler("v-ministareffects-applyRenderConfig", function(_, _, cfg)
    v_ministarEffects_applyRenderConfig(cfg)
  end)

  -- Synchronizes data
  message.setHandler("v-ministareffects-updateBlocks", function(_, _, burningBlocks_, heightMap_, sunProximityRatio_, minHeight_, liquidParticlePoints_)
    burningBlocks = burningBlocks_
    heightMap = vMinistar.HeightMap:new(heightMap_.startXPos, heightMap_.list)
    sunProximityRatio = sunProximityRatio_
    minHeight = minHeight_

    -- Merge on top of existing liquid particle points.
    for chunk, tiles in pairs(liquidParticlePoints_) do
      if #tiles > 0 then
        liquidParticlePoints[chunk] = tiles
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
  lightDrawBounds = {}
  sunProximityRatio = 0

  particleDensity = 0.02
  startBurningColor = {255, 0, 0, 0}
  endBurningColor = {255, 119, 0, 255}
  sunRayDimColor = {255, 0, 0, 0}
  sunRayBrightColor = {255, 216, 107, 128}

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
    local window = rect.pad(world.clientWindow(), 100)

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
    -- Merge on top of existing liquid particle points.
    for chunk, tiles in pairs(liquidParticlePoints_) do
      if #tiles > 0 then
        liquidParticlePoints[chunk] = tiles
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
  if useImagesForRays then
    sunRayDrawable = {
      transformation = {{0, 0, 0}, {0, 0, 0}, {0, 0, 0}},  -- Placeholder
      image = "/scripts/rendering/v-ministarray.png",
      position = {},  -- Placeholder
      color = {},  -- Placeholder
      fullbright = true
    }
    blockDrawable = {  -- Construct table once. position and color will change.
      image = "/scripts/rendering/v-ministarhotspot.png",
      transformation = {
        {1, 0, 0.5},
        {0, 1, 0.5},
        {0, 0, 1}
      },
      width = 8,
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
    sunRayDrawableFunc = function(x, bottomY, topY, predictedPos)
      local relativePos = {x - predictedPos[1], bottomY - predictedPos[2]}

      sunRayDrawable.line = {{0.5, -1}, {0.5, topY - bottomY}}
      sunRayDrawable.position = relativePos
      localAnimator.addDrawable(sunRayDrawable, "Liquid-1")
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
    local boosts = v_ministarEffects_computeSolarFlareBoosts(heightMap.startXPos, heightMap.startXPos + #heightMap.list)

    v_ministarEffects_drawSunRays(predictedPos, sunProximityRatio, boosts, window)
    v_ministarEffects_drawSunRayLights(sunProximityRatio, boosts, window)
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

function v_ministarEffects_drawSunRays(predictedPos, ratio, boosts, window)
  local bottomY = minHeight

  -- Draw sun rays.
  local startX = math.max(world.nearestTo(heightMap.startXPos, window[1]), heightMap.startXPos)
  local endX = math.min(world.nearestTo(heightMap.endXPos, window[3]), heightMap.endXPos)
  for x = startX, endX do
    local i, topY = heightMap:geti(x)

    if topY and topY ~= bottomY then
      sunRayDrawable.color = vAnimator.lerpColor(ratio + boosts[i], sunRayDimColor, sunRayBrightColor)
      sunRayDrawableFunc(x, bottomY, topY, predictedPos)
    end
  end
end

function v_ministarEffects_drawSunRayLights(ratio, boosts, window)
  if not useLights then return end

  local sunRayLightSource = {
    position = true,  -- Placeholder
    color = {0, 0, 0, 0}
  }

  local startX = math.max(window[1], heightMap.startXPos)
  local endX = math.min(window[3], heightMap.endXPos)

  -- Draw lights
  for x = startX, endX do
    local i = x - heightMap.startXPos + 1
    local v = lightDrawBounds[i]
    if v.s ~= v.e then
      local inc
      if v.s < v.e then
        inc = lightInterval
      else
        inc = -lightInterval
      end
      -- local rayRatio = math.min(1.0, ratio + boosts[i])
      -- local rayRatio = ratio + boosts[i]
      local rayRatio = math.min(1.0, math.max(0.0, ratio + boosts[i]))
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
      end
      sunRayLightSource.position = {x, v.e}
      localAnimator.addLightSource(sunRayLightSource)
    end
  end
end

function v_ministarEffects_computeLightBounds()
  if not useLights then return end

  local window = world.clientWindow()

  local bottomY = minHeight

  local lightBottomY = math.max(window[2], bottomY) // lightInterval * lightInterval

  -- Draw sun rays and compute light drawing boundaries based on change in max value.
  local prevTopY = heightMap.list[1]  -- Default
  for i, topY in ipairs(heightMap.list) do
    lightDrawBounds[i] = {s = prevTopY, e = topY}
    prevTopY = topY
  end

  -- Derive a starting index based on startXPos.
  local startI = (heightMap.startXPos // lightInterval + 1) * lightInterval - heightMap.startXPos + 1
  -- Add periodic lights
  for i = startI, #heightMap.list, lightInterval do
    if lightBottomY <= heightMap.list[i] and heightMap.list[i] ~= bottomY then
      lightDrawBounds[i] = {s = lightBottomY, e = heightMap.list[i]}
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
  -- for x = window[1], window[3] do
  --   local y = heightMap:get(x)
  --   if y ~= minHeight and math.random() <= liquidParticleDensity then
  --     localAnimator.spawnParticle(liquidSunParticle, {x, minHeight - (math.random() * 3)})
  --   end
  -- end
  -- for _ = 1, 1 do
  -- end

  for _, tiles in pairs(liquidParticlePoints) do
    for _, tile in ipairs(tiles) do
      if rect.contains(window, tile) and math.random() <= liquidParticleDensity then
        localAnimator.spawnParticle(liquidSunParticle, tile)
      end
    end
  end
  local pos = rect.randomPoint(window)

  local liquid = world.liquidAt(pos)
  if liquid and liquid[1] == sunLiquidId then
    localAnimator.spawnParticle(liquidSunParticleLarge, pos)
  end
end

function v_ministarEffects_computeSolarFlareBoosts(startX, endX)
  --[[
    Schema: {
      x: integer,  // Where the solar flare is located
      startTime: number,  // World time at which the solar flare started
      duration: number,  // How long the flare lasts.
      potency: number,  // Between 0 and 1. How potent the solar flare is.
      spread: number  // Controls the width of the solar flare.
    }[]
  ]]
  local solarFlares = world.getProperty("v-solarFlares") or {}

  sb.setLogMap("solarFlares", "%s", #solarFlares)

  local boosts = {}
  for x = startX, endX do
    boosts[x - startX + 1] = 0
  end
  for _, flare in ipairs(solarFlares) do
    local durationStdDev = flare.duration / 6
    local durationMean = flare.startTime + flare.duration / 2
    local timeMultiplier = v_ministarEffects_normalDistribution(durationMean, durationStdDev, world.time())

    for x = startX, endX do
      local i = x - startX + 1
      boosts[i] = boosts[i] + v_ministarEffects_normalDistribution(flare.x, flare.spread / 3, x) * flare.potency * timeMultiplier
    end
  end

  return boosts
end

function v_ministarEffects_normalDistribution(mean, stdDev, x)
  return math.exp(-(x - mean) ^ 2 / (2 * stdDev ^ 2))
end