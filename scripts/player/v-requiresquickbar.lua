--[[
  Script that shows a simple warning to the player that Voided requires a Quickbar mod if the player doesn't have one
  installed.
]]

local expectedPopupId
local showMessageInterval
local showMessageDelay
local showMessageTimer

function init()
  expectedPopupId = "Quickbar"
  showMessageInterval = 60 * 60 * 24  -- measured in the number of seconds
  -- showMessageInterval = 1  -- measured in the number of seconds
  showMessageDelay = 60  -- measured in the number of ticks
  showMessageTimer = showMessageDelay

  if storage.showAgain == nil then
    storage.showAgain = true
  end

  message.setHandler("v-neverShowAgain-" .. expectedPopupId, function()
    storage.showAgain = false
  end)

  local status, _ = pcall(root.assetJson, "/quickbar/icons.json")

  if not status then
    sb.logWarn("[Voided: Expansion Mod] Could not load file '/quickbar/icons.json'. Assuming no Quickbar mod is installed.")
  else
    script.setUpdateDelta(0)  -- Don't show message
  end
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

  local configData = root.assetJson("/interface/scripted/v-quickbarwarning/v-quickbarwarning.config")
  configData.popupId = expectedPopupId
  player.interact("ScriptPane", configData)
end