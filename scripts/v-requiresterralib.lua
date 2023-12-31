--[[
  Script that shows a simple warning to the player that Voided will be requiring TerraLib.
]]

local showMessageInterval
local showMessageDelay
local showMessageTimer

function init()
  showMessageInterval = 86400  -- measured in the number of seconds
  showMessageDelay = 60  -- measured in the number of ticks
  showMessageTimer = showMessageDelay
  
  if storage.showAgain == nil then
    storage.showAgain = true
  end
  
  message.setHandler("v-neverShowAgain", function()
    storage.showAgain = false
  end)
end

function update(dt)
  if showMessageTimer then
    showMessageTimer = showMessageTimer - 1
    -- If the message should be shown again and either of the following is true: storage.lastShown is undefined or more 
    -- than showMessageInterval seconds has passed since the message was last shown...
    if not messageShown and storage.showAgain and showMessageTimer <= 0 and 
        (not storage.lastShown or os.time() > storage.lastShown + showMessageInterval) then
      showMessage()
      showMessageTimer = nil
    end
  end
end

function showMessage()
  storage.lastShown = os.time()
  messageShown = true

  local configData = root.assetJson("/interface/scripted/v-terralibwarning/v-terralibwarning.config")
  player.interact("ScriptPane", configData, player.id())
end