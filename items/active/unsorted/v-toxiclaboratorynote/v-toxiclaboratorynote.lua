require "/scripts/voidedutil.lua"

local displayText
local promise
local promiseFailed
local displayCoords

function init()
  -- Two underscores signifies that it's a private parameter--i.e., modders shouldn't override this parameter except 
  -- through
  displayCoords = config.getParameter("__displayCoords")

  -- Set initial display text
  updateDisplayText()
end

function update(dt)
  -- If displayCoords aren't defined yet and the promise hasn't failed...
  if not displayCoords and not promiseFailed then
    -- If a promise has not been set out yet...
    if not promise then
      promise = world.findUniqueEntity(config.getParameter("targetUid"))
    elseif promise:finished() then  -- Otherwise, if the promise has finished...
      -- If the promise was successful...
      if promise:succeeded() then
        -- Set displayCoords to the result of converting the promise result into display coordinates.
        displayCoords = getDisplayCoords(promise:result())
        activeItem.setInstanceValue("__displayCoords", displayCoords)
        updateDisplayText()
      else
        sb.logError("Promise failed while trying to get position of unique entity: %s", promise:error())
        promiseFailed = true  -- Set promiseFailed to true to prevent this hook from spamming log messages.
      end
    end
  end
end

function getDisplayCoords(coordinates)
  -- Get parameters.
  local coordObfuscation = config.getParameter("obfuscatedDigits")
  local obfuscationCharacter = config.getParameter("obfuscationCharacter", "_")

  -- Stringify coords
  local coordinatesStringified = {tostring(math.floor(coordinates[1])), tostring(math.floor(coordinates[2]))}
  local coordObfuscationRange = config.getParameter("coordObfuscationRange")
  
  -- Generate coordinates (obfuscated)
  return string.format("X: %s, Y: %s",
    voidedUtil.obfuscateStringMinMax(coordinatesStringified[1], coordObfuscationRange[1], coordObfuscationRange[2], obfuscationCharacter),
    voidedUtil.obfuscateStringMinMax(coordinatesStringified[2], coordObfuscationRange[1], coordObfuscationRange[2], obfuscationCharacter)
  )
end

function updateDisplayText()
  -- Get parameters
  local baseNoteText = config.getParameter("noteText", "")
  -- Display an error message if displayCoords are not defined.
  displayText = string.format("%s\n\n%s", baseNoteText, displayCoords or config.getParameter("coordsErrorMessage"))
end

function activate()
  local configData = root.assetJson("/interface/scripted/papernote/papernotegui.config")
  configData.noteText = displayText
  activeItem.interact("ScriptPane", configData)
  
  -- If the player has not read this note yet and displayCoords is defined...
  if not config.getParameter("__hasReadNote") and displayCoords then
    -- Spawn a new instance of the current item with an updated description and __hasReadNote set to true. This 
    -- forces the item to rebuild. Note that any other parameters are lost.
    world.spawnItem(config.getParameter("itemName"), mcontroller.position(), 1, {
      __hasReadNote = true,
      __displayCoords = displayCoords,
      -- Append the display coordinates to the description...
      description = string.format("%s %s", config.getParameter("description"), displayCoords),
      targetUid = config.getParameter("targetUid"),
      obfuscationCharacter = config.getParameter("obfuscationCharacter"),
      seed = config.getParameter("seed")
    })
    
    -- Delete old item.
    item.consume(1)
  end
end