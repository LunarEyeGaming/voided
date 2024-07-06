require "/scripts/util.lua"
require "/scripts/rect.lua"

local interactive

local translationTime
local translationLength
local direction
local frames
local isSolid
local useHorizontal
local openMaterial
local openMaterialSpaces
local closeMaterial
local closeMaterialSpaces
local useSpacesTransition
local openTranslationDelay
local closeTransitionDelay
local endOffset
local translationTimer
local openTranslationDelayTimer
local closeTranslationDelayTimer
local useAntiCrush
local forceRegion
local queryArea

local isMoving  -- Whether it is moving in the current tick
local wasMoving  -- Whether it was moving in the previous tick

function init()
  interactive = config.getParameter("interactive", false)

  local translationConfig = config.getParameter("translationConfig")

  translationTime = translationConfig.duration  ---@type number # The amount of time the translation takes
  translationLength = translationConfig.distance  ---@type number # How much to move by.
  ---@type 1 | -1 # The direction to translate the door when opening. 1 for right / up, -1 for left / down.
  direction = translationConfig.direction or 1
  frames = translationConfig.frames or 1  ---@type integer # The number of frames for the image.
  isSolid = translationConfig.isSolid  ---@type boolean # Whether or not the door is solid (e.g., for background doors).
  useHorizontal = translationConfig.useHorizontal  ---@type boolean # `true` for horizontal movement, `false` otherwise.
  ---@type boolean? # Whether or not to use a transition for the material spaces. Not applicable if `isSolid` is `false`
  useSpacesTransition = translationConfig.useSpacesTransition
  ---@type number? # The amount of time to wait before opening the door.
  openTranslationDelay = translationConfig.openDelay or 0
  ---@type number? # The amount of time to wait before closing the door.
  closeTransitionDelay = translationConfig.closeDelay or 0

  ---@type string? # The material to use for empty spaces. Not applicable if `isSolid` is `false`.
  openMaterial = config.getParameter("openMaterial")
  ---@type string? # The material to use for door spaces. Not applicable if `isSolid` is `false`.
  closeMaterial = config.getParameter("closeMaterial", "metamaterial:door")
  ---@type [Vec2I, string][]? # A list of associations between spaces and materials to use for empty spaces. Not
  ---applicable if `isSolid` is `false`.
  openMaterialSpaces = config.getParameter("openMaterialSpaces")
  ---@type [Vec2I, string][]? # A list of associations between spaces and materials to use for door spaces. Not
  ---applicable if `isSolid` is `false`.
  closeMaterialSpaces = config.getParameter("closeMaterialSpaces")

  if useHorizontal then
    endOffset = {direction * translationLength, 0}
  else
    endOffset = {0, direction * translationLength}
  end
  translationTimer = 0
  openTranslationDelayTimer = 0
  closeTranslationDelayTimer = 0

  if isSolid then
    if not storage.states then
      setupMaterialSpaces()
    end

    -- Set initial material spaces
    object.setMaterialSpaces(storage.spaceStates[1])
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

  object.setInteractive(interactive)
end

function update(dt)
  wasMoving = isMoving

  if storage.active then
    -- If the delay has ended...
    if openTranslationDelayTimer <= 0 then
      translationTimer = math.min(translationTime, translationTimer + dt)

      isMoving = translationTimer < translationTime
    else
      openTranslationDelayTimer = openTranslationDelayTimer - dt
    end
  else
    -- If the delay has ended...
    if closeTranslationDelayTimer <= 0 then
      -- If we are not using anti-crush or there are no entities present in the query area...
      if not useAntiCrush or #world.entityQuery(rect.ll(queryArea), rect.ur(queryArea), {includedTypes = {"monster", "npc", "player"}}) <= 0 then
        translationTimer = math.max(0, translationTimer - dt)

        isMoving = translationTimer > 0
      end
    else
      closeTranslationDelayTimer = closeTranslationDelayTimer - dt
    end
  end

  local progress = translationTimer / translationTime

  if isSolid and (isMoving or wasMoving) then
    if useSpacesTransition then
      object.setMaterialSpaces(storage.spaceStates[math.floor(util.lerp(progress, 1, #storage.spaceStates))])
    else
      -- This value should be true if the door is "active" and openTranslationDelayTimer <= 0, or door is not "active"
      -- and closeTransitionDelayTimer > 0.
      local shouldUseOpenSpaces = storage.active and openTranslationDelayTimer <= 0 or closeTranslationDelayTimer > 0
      object.setMaterialSpaces(storage.spaceStates[shouldUseOpenSpaces and 2 or 1])
    end
  end

  updateSounds()

  updateDoor(progress, endOffset)
end

function onNodeConnectionChange(args)
  object.setInteractive(not object.isInputNodeConnected(0))
  updateActive((not object.isInputNodeConnected(0)) or object.getInputNodeLevel(0)) -- Closed if input node is connected and input is off
end

function onInputNodeChange(args)
  updateActive((not object.isInputNodeConnected(0)) or object.getInputNodeLevel(0)) -- Closed if input node is connected and input is off
end

function onInteraction()
  updateActive(not storage.active)
end

function updateActive(active)
  storage.active = active

  -- If active...
  if storage.active then
    openTranslationDelayTimer = openTranslationDelay
  else
    closeTranslationDelayTimer = closeTransitionDelay
  end
end

function setupMaterialSpaces()
  local spaces = object.spaces()
  storage.spaceStates = {}

  -- If we should make space states follow a smooth transition...
  if useSpacesTransition then
    if useHorizontal then
      local xRange = getXRange(spaces)

      -- Flip xRange components if the direction is inverted.
      if direction == -1 then
        xRange = {xRange[2], xRange[1]}
      end

      -- For each slice of the space region...
      for x = xRange[1], xRange[2], direction do
        local spaceState = getXSpacesForSlice(spaces, x)

        table.insert(storage.spaceStates, spaceState)
      end
    else
      local yRange = getYRange(spaces)

      -- Flip yRange if the direction is inverted
      if direction == -1 then
        yRange = {yRange[2], yRange[1]}
      end

      -- For each slice of the space region...
      for y = yRange[1], yRange[2], direction do
        local spaceState = getYSpacesForSlice(spaces, y)

        table.insert(storage.spaceStates, spaceState)
      end
    end
  else
    -- Add a space state that is all door spaces.
    local spaceState = {}

    for _, space in ipairs(spaces) do
      local material = closeMaterialForSpace(space)

      if material then
        table.insert(spaceState, {space, material})
      end
    end

    table.insert(storage.spaceStates, spaceState)
  end

  -- Add a final space state that consists of only openMaterial if there is an openMaterial.
  local spaceState = {}

  if openMaterial or openMaterialSpaces then
    for _, space in ipairs(spaces) do
      local material = openMaterialForSpace(space)

      if material then
        table.insert(spaceState, {space, material})
      end
    end
  end

  table.insert(storage.spaceStates, spaceState)
end

---Returns the horizontal boundaries of the spaces in poly `poly`.
---@param poly PolyF the poly from which to get the horizontal boundaries.
---@return [number, number]
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

---Returns the vertical boundaries of the spaces in poly `poly`.
---@param poly PolyF the poly from which to get the vertical boundaries.
---@return [number, number]
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

---Returns the spaces to the left (if `direction` is -1) / to the right (if `direction` is 1) of and including the
---vertical strip at `x`.
---@param spaces PolyI the positions of the spaces to use (relative to the object's position)
---@param x integer the horizontal position of the slice (relative to the object's position)
---@return [Vec2I, string][]
function getXSpacesForSlice(spaces, x)
  local spaceState = {}

  -- For each space...
  for _, space in ipairs(spaces) do
    -- If the space is to the left of the slice (when the direciton is inverted) / to the right of the slice (when
    -- the direction is not inverted)...
    if (direction == -1 and space[1] <= x) or (direction == 1 and space[1] >= x) then
      -- The material to use for a door space
      local material = closeMaterialForSpace(space)

      if material then
        table.insert(spaceState, {space, material})
      end
    else
      -- The material to use for an open space
      local material = openMaterialForSpace(space)

      if material then
        table.insert(spaceState, {space, material})
      end
    end
  end

  return spaceState
end

---Returns the spaces below (if `direction` is -1) / above (if `direction` is 1) of and including the horizontal strip
---at `y`.
---@param spaces PolyI the positions of the spaces to use (relative to the object's position)
---@param y integer the vertical position of the slice (relative to the object's position)
---@return [Vec2I, string][]
function getYSpacesForSlice(spaces, y)
  local spaceState = {}

  -- For each space...
  for _, space in ipairs(spaces) do
    -- If the space is to the left of the slice (when the direciton is inverted) / to the right of the slice (when
    -- the direction is not inverted)...
    if (direction == -1 and space[2] <= y) or (direction == 1 and space[2] >= y) then
      -- The material to use for a door space
      local material = closeMaterialForSpace(space)

      if material then
        table.insert(spaceState, {space, material})
      end
    else
      -- The material to use for an open space
      local material = openMaterialForSpace(space)

      if material then
        table.insert(spaceState, {space, material})
      end
    end
  end

  return spaceState
end

---Returns the material to use for space `space` when the door is opened, or `openMaterial` if there is no
---space-specific material defined for `space` (or `openMaterialSpaces` is `nil`).
---@param space Vec2I
---@return string
function openMaterialForSpace(space)
  if openMaterialSpaces then
    -- For each open material space...
    for _, otherSpace in ipairs(openMaterialSpaces) do
      -- If the open space's position matches space's position...
      if (vec2.eq(otherSpace[1], space)) then
        return otherSpace[2]
      end
    end
  end

  return openMaterial  -- Default value to use.
end

---Returns the material to use for space `space` when the door is closed, or `openMaterial` if there is no
---space-specific material defined for `space` (or `openMaterialSpaces` is `nil`).
---@param space Vec2I
---@return string
function closeMaterialForSpace(space)
  if closeMaterialSpaces then
    -- For each open material space...
    for _, otherSpace in ipairs(closeMaterialSpaces) do
      -- If the open space's position matches space's position...
      if (vec2.eq(otherSpace[1], space)) then
        return otherSpace[2]
      end
    end
  end

  return closeMaterial  -- Default value to use.
end


---To be run on every tick. Plays the appropriate sounds depending on the current state of the sliding door.
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

---Plays a sound and (optionally) loops it if the animator has it and has no effect otherwise.
---@param soundName string the name of the sound to play.
---@param loopCount integer? (optional) the number of times to loop the sound.
function playOptionalSound(soundName, loopCount)
  if animator.hasSound(soundName) then
    animator.playSound(soundName, loopCount)
  end
end

---Stops a sound if the animator has it and has no effect otherwise.
---@param soundName string the name of the sound to stop.
function stopOptionalSound(soundName)
  if animator.hasSound(soundName) then
    animator.stopAllSounds(soundName)
  end
end

---Updates the door's visuals based on the progress `progress` and the target offset `endOffset`.
---@param progress number
---@param endOffset Vec2F
function updateDoor(progress, endOffset)
  animator.setGlobalTag("doorProgress", tostring(math.floor(util.lerp(progress, 1, frames))))
  animator.resetTransformationGroup("door")
  animator.translateTransformationGroup("door", {
    util.lerp(progress, 0, endOffset[1]),
    util.lerp(progress, 0, endOffset[2])
  })

  if useAntiCrush then
    physics.setForceEnabled(forceRegion, storage.active)
  end
end