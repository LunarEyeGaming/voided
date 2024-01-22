require "/scripts/util.lua"
require "/scripts/rect.lua"

local translationTime
local translationLength
local direction
local frames
local isSolid
local useHorizontal
local openMaterial
local endOffset
local translationTimer
local useAntiCrush
local forceRegion
local queryArea

local isMoving  -- Whether it is moving in the current tick
local wasMoving  -- Whether it was moving in the previous tick

function init()
  local translationConfig = config.getParameter("translationConfig")
  translationTime = translationConfig.duration
  translationLength = translationConfig.distance  -- How much to move by.
  direction = translationConfig.direction or 1
  frames = translationConfig.frames or 1
  isSolid = translationConfig.isSolid
  useHorizontal = translationConfig.useHorizontal
  openMaterial = translationConfig.openMaterial
  
  if useHorizontal then
    endOffset = {direction * translationLength, 0}
  else
    endOffset = {0, direction * translationLength}
  end
  translationTimer = 0
  
  if isSolid and not storage.spaceStates then
    setupMaterialSpaces()
  end
  
  if storage.active == nil then
    updateActive()
  end
  
  useAntiCrush = config.getParameter("useAntiCrush", false)
  if useAntiCrush then
    forceRegion = object.direction() == 1 and "doorLeft" or "doorRight"
    queryArea = rect.translate(config.getParameter("queryArea"), object.position())
  end
  
  for sound, offset in pairs(config.getParameter("soundOffsets", {})) do
    animator.setSoundPosition(sound, offset)
  end
  
  isMoving = false
end

function update(dt)
  wasMoving = isMoving

  if storage.active then
    translationTimer = math.min(translationTime, translationTimer + dt)

    isMoving = translationTimer < translationTime
  else
    if not useAntiCrush or #world.entityQuery(rect.ll(queryArea), rect.ur(queryArea), {includedTypes = {"monster", "npc", "player"}}) <= 0 then
      translationTimer = math.max(0, translationTimer - dt)

      isMoving = translationTimer > 0
    end
  end
  
  local progress = translationTimer / translationTime
  
  if isSolid then
    object.setMaterialSpaces(storage.spaceStates[math.floor(util.lerp(progress, 1, #storage.spaceStates))])
  end
  
  updateSounds()
  
  animator.setGlobalTag("doorProgress", math.floor(util.lerp(progress, 1, frames)))
  animator.resetTransformationGroup("door")
  animator.translateTransformationGroup("door", {
    util.lerp(progress, 0, endOffset[1]),
    util.lerp(progress, 0, endOffset[2])
  })
  
  if useAntiCrush then
    physics.setForceEnabled(forceRegion, storage.active)
  end
end

function onNodeConnectionChange(args)
  updateActive()
end

function onInputNodeChange(args)
  updateActive()
end

function updateActive()
  storage.active = (not object.isInputNodeConnected(0)) or object.getInputNodeLevel(0) -- Closed if no input node connected or input is off
end

function setupMaterialSpaces()
  local spaces = object.spaces()
  storage.spaceStates = {}
  
  if useHorizontal then
    local xRange = getXRange(spaces)
    -- WARNING: SPAGHETTI CODE! DO NOT REPLICATE UNLESS YOU WANT YOUR HEAD TO HURT!
    if direction == -1 then
      xRange = {xRange[2], xRange[1]}
    end
    
    for x = xRange[1], xRange[2], direction do
      local spaceState = {}
      for _, space in ipairs(spaces) do
        if (direction == -1 and space[1] <= x) or (direction == 1 and space[1] >= x) then
          table.insert(spaceState, {space, "metamaterial:door"})
        elseif openMaterial then
          table.insert(spaceState, {space, openMaterial})
        end
      end
      table.insert(storage.spaceStates, spaceState)
    end
  else
    local yRange = getYRange(spaces)
    if direction == -1 then
      yRange = {yRange[2], yRange[1]}
    end
    
    for y = yRange[1], yRange[2], direction do
      local spaceState = {}
      for _, space in ipairs(spaces) do
        if (direction == -1 and space[2] <= y) or (direction == 1 and space[2] >= y) then
          table.insert(spaceState, {space, "metamaterial:door"})
        elseif openMaterial then
          table.insert(spaceState, {space, openMaterial})
        end
      end
      table.insert(storage.spaceStates, spaceState)
    end
  end
  
  local spaceState = {}

  if openMaterial then
    for _, space in ipairs(spaces) do
      table.insert(spaceState, {space, openMaterial})
    end
  end

  table.insert(storage.spaceStates, spaceState)
end

function getXRange(poly)
  local minX = math.huge
  local maxX = -math.huge
  for _, point in ipairs(poly) do
    if point[1] > maxX then
      maxX = point[1]
    end
    if point[1] < minX then
      minX = point[1]
    end
  end
  return {minX, maxX}
end

function getYRange(poly)
  local minY = math.huge
  local maxY = -math.huge
  for _, point in ipairs(poly) do
    if point[2] > maxY then
      maxY = point[2]
    end
    if point[2] < minY then
      minY = point[2]
    end
  end
  return {minY, maxY}
end

--[[
  To be run on every tick. Plays the appropriate sounds depending on the current state of the sliding door.
]]
function updateSounds()
  -- Began movement
  if isMoving and not wasMoving then
    playOptionalSound("moveLoop", -1)
    playOptionalSound("moveStart")
  end
  
  -- Ended movement (should be mutually exclusive with the previous condition)
  if not isMoving and wasMoving then
    playOptionalSound("moveEnd")
    stopOptionalSound("moveLoop")
  end
end

--[[
  Plays a sound and (optionally) loops it if the animator has it and has no effect otherwise.
  
  soundName: the name of the sound to play.
  loopCount: (optional) the number of times to loop the sound.
]]
function playOptionalSound(soundName, loopCount)
  if animator.hasSound(soundName) then
    animator.playSound(soundName, loopCount)
  end
end

--[[
  Stops a sound if the animator has it and has no effect otherwise.
  
  soundName: the name of the sound to stop.
]]
function stopOptionalSound(soundName)
  if animator.hasSound(soundName) then
    animator.stopAllSounds(soundName)
  end
end