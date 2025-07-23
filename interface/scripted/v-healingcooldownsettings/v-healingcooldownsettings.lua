require "/scripts/v-util.lua"

-- HOOKS & CALLBACKS
function init()
  getSettings()
end

function update(dt)
end

function dismissed()
end

function btnReset()
  local defaults = root.assetJson("/v-healingcooldowndefaults.config")
  populateSettings(defaults)

  applySettings()
end

function btnApply()
  applySettings()
end

function btnCancel()
  pane.dismiss()
end

function updateDisplayWidget(widgetName, widgetData)
  local v = widget.getSliderValue(widgetName)

  widget.setText(widgetData.displayWidget, tostring(v))
end

function createTooltip(screenPosition)
  local child = widget.getChildAt(screenPosition)
  if child then
    if vUtil.strStartsWith(child, ".") then
      child = child:sub(2)
    end
    local data = widget.getData(child)
    if data then
      return data.tooltipText
    end
  end
end

-- HELPER FUNCTIONS
function getSettings()
  local defaults = root.assetJson("/v-healingcooldowndefaults.config")
  local cfg = player.getProperty("v-healingCooldownSettings", defaults)
  populateSettings(cfg)
end

function applySettings()
  local cfg = {
    fastCooldown = widget.getSliderValue("sldFastCooldown"),
    slowCooldown = widget.getSliderValue("sldSlowCooldown")
  }
  player.setProperty("v-healingCooldownSettings", cfg)
end

function populateSettings(cfg)
  if cfg then
    updateSlider("sldFastCooldown", cfg.fastCooldown)
    updateSlider("sldSlowCooldown", cfg.slowCooldown)
  end
end

function updateSlider(name, value)
  widget.setSliderValue(name, value)

  local data = widget.getData(name)
  -- Update display widget as well if provided.
  if data and data.displayWidget then
    widget.setText(data.displayWidget, tostring(value))
  end
end