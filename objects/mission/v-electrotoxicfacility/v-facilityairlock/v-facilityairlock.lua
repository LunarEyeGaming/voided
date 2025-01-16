require "/scripts/interp.lua"
require "/scripts/vec2.lua"

local rotationTime
local hingePoint
local startRotation
local endRotation

local doorSpaces
local openDoorSpaces

local isMoving
local wasMoving
local rotationTimer

function init()
  rotationTime = config.getParameter("rotationTime")
  hingePoint = config.getParameter("hingePoint")
  startRotation = config.getParameter("startRotation") * math.pi / 180  -- To radians
  endRotation = config.getParameter("endRotation") * math.pi / 180  -- To radians

  rotationTimer = 0

  -- Default value for storage.active
  if storage.active == nil then
    storage.active = false
  end

  setupMaterialSpaces()
end

function update(dt)
  -- Update rotation timer based on whether the door is opening or closing. Also update isMoving status.
  if storage.active then
    rotationTimer = math.min(rotationTime, rotationTimer + dt)
    isMoving = rotationTimer < rotationTime
  else
    rotationTimer = math.max(0, rotationTimer - dt)
    isMoving = rotationTimer > 0
  end

  -- If the object has just started moving, clear material spaces
  if isMoving and not wasMoving then
    object.setMaterialSpaces()
  end

  -- If the object has just stopped moving, set material spaces to open or closed depending on whether the door is
  -- active.
  if not isMoving and wasMoving then
    object.setMaterialSpaces(storage.active and openDoorSpaces or doorSpaces)
  end

  -- Update rotation
  local rotation = interp.linear(rotationTimer / rotationTime, startRotation, endRotation)
  animator.resetTransformationGroup("door")
  animator.rotateTransformationGroup("door", rotation, hingePoint)

  updateSounds()

  wasMoving = isMoving
end

function onNodeConnectionChange()
  storage.active = not object.isInputNodeConnected(0) or object.getInputNodeLevel(0) -- Closed if input node is connected and input is off
end

function onInputNodeChange()
  storage.active = not object.isInputNodeConnected(0) or object.getInputNodeLevel(0) -- Closed if input node is connected and input is off
end

function setupMaterialSpaces()
  doorSpaces = config.getParameter("closedMaterialSpaces")

  if not doorSpaces then
    doorSpaces = {}
    local spaces = object.spaces()

    for _, space in ipairs(spaces) do
      table.insert(doorSpaces, {space, "metamaterial:door"})
    end
  end

  if not storage.active then
    object.setMaterialSpaces(doorSpaces)
  end

  openDoorSpaces = config.getParameter("openMaterialSpaces", {})
end

---To be run on every tick. Plays the appropriate sounds depending on the current state of the sliding door.
function updateSounds()
  -- Began movement
  if isMoving and not wasMoving then
    playOptionalSound("moveLoop", -1)
    playOptionalSound("moveStart")
    -- animator.setSoundPitch("moveLoop", 1.5, 1.0)
    -- animator.setSoundVolume("moveLoop", 1.0, 1.0)
  end

  -- Ended movement (should be mutually exclusive with the previous condition)
  if not isMoving and wasMoving then
    playOptionalSound("moveEnd")
    stopOptionalSound("moveLoop")
    -- animator.setSoundPitch("moveLoop", 0.5)
    -- animator.setSoundVolume("moveLoop", 0.0)
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

---Callscript funcion.
---@param capability string
---@return boolean
function hasCapability(capability)
  if object.isInputNodeConnected(0) then
    return false
  elseif capability == 'door' then
    return true
  elseif capability == 'closedDoor' then
    return not storage.active
  elseif capability == 'openDoor' then
    return storage.active
  else
    return false
  end
end