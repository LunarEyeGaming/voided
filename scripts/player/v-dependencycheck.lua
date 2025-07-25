--[[
  Script that shows a simple warning to the player for each mod that Voided requires but the player doesn't have
  installed.
]]

--[[
  TESTS:
  * No missing mods
  * One missing mod
  * Two missing mods.
  * showAgain is set to false
  * lastShown functionality
]]

---@class RequiredMod
---@field name string
---@field checkType "json" | "lua"
---@field checkFile string
---@field popupConfig string
---@field popupInterval number

local requiredMods  ---@type RequiredMod[]

local missingMods

local popupData

local showMessagesDelay
local showMessagesTimer

function init()
  requiredMods = root.assetJson("/v-dependencies.config")

  missingMods = {}

  showMessagesDelay = 60  -- measured in the number of ticks
  showMessagesTimer = showMessagesDelay

  initializePopupData()

  message.setHandler("v-neverShowAgain", function(_, _, modName)
    popupData[modName].showAgain = false
  end)

  checkDependencies()
end

function update(dt)
  if showMessagesTimer then
    showMessagesTimer = showMessagesTimer - 1

    -- If the timer has expired...
    if showMessagesTimer <= 0 then
      -- For each missing mod...
      for _, i in ipairs(missingMods) do
        local mod = requiredMods[i]
        local modPopupData = popupData[mod.name]

        -- If it should be shown again and it has not been shown before or it has been popupInterval seconds since the
        -- last time it was shown...
        if modPopupData.showAgain and
            (not modPopupData.lastShown or os.time() > modPopupData.lastShown + mod.popupInterval) then
          showMessage(mod.name, mod.popupConfig, modPopupData)
        end
      end

      showMessagesTimer = nil
    end
  end
end

function showMessage(modName, popupConfig, modPopupData)
  modPopupData.lastShown = os.time()

  local configData = root.assetJson(popupConfig)
  configData.popupId = modName
  player.interact("ScriptPane", configData)
end

function initializePopupData()
  if storage.popupData == nil then
    storage.popupData = {}
  end

  popupData = storage.popupData

  for i, v in ipairs(requiredMods) do
    local name = v.name

    if not name then
      error("Entry " .. i .. " does not have defined name.")
    end

    if popupData[name] == nil then
      popupData[name] = {showAgain = true, lastShown = nil}
    end

    -- popupData[name] = {showAgain = true, lastShown = nil}
  end
end

function checkDependencies()
  for i, v in ipairs(requiredMods) do
    -- Save functions
    local tempInit, tempUpdate, tempShowMessage = init, update, showMessage
    local tempInitializePopupData, tempCheckDependencies = initializePopupData, checkDependencies

    -- Check the file.
    local status
    if v.checkType == "json" then
      status, _ = pcall(root.assetJson, v.checkFile)
    elseif v.checkType == "lua" then
      status, _ = pcall(require, v.checkFile)
    else
      error("Unknown check type '" .. v.checkType .. "'")
    end

    if not status then
      sb.logWarn("[Voided: Expansion Mod] Could not load file '%s'. Assuming %s is not installed.", v.checkFile, v.name)
      table.insert(missingMods, i)
    else
      init, update, showMessage = tempInit, tempUpdate, tempShowMessage
      initializePopupData, checkDependencies = tempInitializePopupData, tempCheckDependencies
    end
  end
end