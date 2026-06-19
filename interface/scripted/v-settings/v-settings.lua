require "/scripts/v-util.lua"

local layouts
local managers

-- HOOKS & CALLBACKS
function init()
  layouts = config.getParameter("layouts")
  managers = {
    mechanics = VMechanics:new(),
    rendering = VMinistarRendering:new()
  }

  for _, cls in pairs(managers) do
    cls:getSettings()
  end

  changeTab(layouts[1])
end

function update(dt)
end

function dismissed()
end

function btnReset()
  for _, cls in pairs(managers) do
    cls:resetSettings()
  end
end

function btnApply()
  for _, cls in pairs(managers) do
    cls:applySettings(cls:extractSettings())
  end
end

function btnCancel()
  pane.dismiss()
end

function tabsGroup(button, data)
  changeTab(data.selectLayout)
end

function ambientLightPrecision()
  managers.rendering.changed = true
end

function btnAmbientLight()
  managers.rendering.changed = true
end

function btnPrettyRays()
  managers.rendering.changed = true
end

function btnLiquidParticles()
  managers.rendering.changed = true
end

function btnUseSpecial2ForAimableDash()
  managers.mechanics.changed = true
end

function updateDisplayWidget(widgetName, widgetData)
  local v = widget.getSliderValue(widgetData.ownPath)

  managers[widgetData.managerGroup].changed = true

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
---@class VSettingsManager
---@field defaultsLocation string
---@field propertyName string
VSettingsManager = {changed = false}

---@return VSettingsManager
function VSettingsManager:new(obj)
  obj = obj or {}

  setmetatable(obj, self)
  self.__index = self
  return obj
end

function VSettingsManager:getSettings()
  local defaults = root.assetJson("/v-defaultsettings.config:"..self.defaultsLocation)
  local cfg = player.getProperty(self.propertyName, defaults)
  self:populateSettings(cfg)
end

function VSettingsManager:resetSettings()
  local defaults = root.assetJson("/v-defaultsettings.config:"..self.defaultsLocation)
  self:populateSettings(defaults)
  self.changed = true
  self:applySettings(defaults)
end

function VSettingsManager:applySettings(cfg)
  if not self.changed then return end

  player.setProperty(self.propertyName, cfg)
end

function VSettingsManager:populateSettings(cfg)
  error("Not implemented")
end


function VSettingsManager:extractSettings(cfg)
  error("Not implemented")
end

VMechanics = VSettingsManager:new{
  defaultsLocation = "mechanics",
  propertyName = "v-healingCooldownSettings"
}

function VMechanics:extractSettings()
  return {
    fastCooldown = widget.getSliderValue("mechanics.sldFastCooldown"),
    slowCooldown = widget.getSliderValue("mechanics.sldSlowCooldown"),
    useSpecial2 = widget.getChecked("mechanics.btnUseSpecial2ForAimableDash")
  }
end

function VMechanics:applySettings(cfg)
  VSettingsManager.applySettings(self, cfg)
  if not self.changed then return end
  world.sendEntityMessage(player.id(), "v-aimabledashcontrols-setUseSpecial2", cfg.useSpecial2)
end

function VMechanics:populateSettings(cfg)
  if cfg then
    updateSlider("mechanics.sldFastCooldown", cfg.fastCooldown)
    updateSlider("mechanics.sldSlowCooldown", cfg.slowCooldown)
    widget.setChecked("mechanics.btnUseSpecial2ForAimableDash", cfg.useSpecial2)
  end
end

VMinistarRendering = VSettingsManager:new{
  defaultsLocation = "ministarRendering",
  propertyName = "v-ministareffects-renderConfig"
}

function VMinistarRendering:extractSettings()
  return {
    lightIntervalIdx = widget.getSelectedOption("ministarRendering.ambientLightPrecision") + 2,
    useLights = widget.getChecked("ministarRendering.btnAmbientLight"),
    useImagesForRays = widget.getChecked("ministarRendering.btnPrettyRays"),
    useLiquidParticles = widget.getChecked("ministarRendering.btnLiquidParticles")
  }
end

function VMinistarRendering:applySettings(cfg)
  VSettingsManager.applySettings(self, cfg)
  if not self.changed then return end
  world.sendEntityMessage(player.id(), "v-ministareffects-applyRenderConfig", cfg)
end

function VMinistarRendering:populateSettings(cfg)
  widget.setSelectedOption("ministarRendering.ambientLightPrecision", cfg.lightIntervalIdx - 2)
  widget.setChecked("ministarRendering.btnAmbientLight", cfg.useLights)
  widget.setChecked("ministarRendering.btnPrettyRays", cfg.useImagesForRays)
  widget.setChecked("ministarRendering.btnLiquidParticles", cfg.useLiquidParticles)
end

-- healingCooldown = {}

-- healingCooldown.changed = false
-- healingCooldown.defaultsLocation = "healingCooldown"

-- function healingCooldown.getSettings()
--   local defaults = root.assetJson("/v-defaultsettings.config:"..healingCooldown.defaultsLocation)
--   local cfg = player.getProperty("v-healingCooldownSettings", defaults)
--   healingCooldown.populateSettings(cfg)
-- end

-- function healingCooldown.resetSettings()
--   local defaults = root.assetJson("/v-defaultsettings.config:healingCooldown")
--   healingCooldown.populateSettings(defaults)
-- end

-- function healingCooldown.applySettings()
--   local cfg = {
--     fastCooldown = widget.getSliderValue("healingCooldown.sldFastCooldown"),
--     slowCooldown = widget.getSliderValue("healingCooldown.sldSlowCooldown")
--   }
--   player.setProperty("v-healingCooldownSettings", cfg)
-- end

-- function healingCooldown.populateSettings(cfg)
--   if cfg then
--     updateSlider("healingCooldown.sldFastCooldown", cfg.fastCooldown)
--     updateSlider("healingCooldown.sldSlowCooldown", cfg.slowCooldown)
--   end
-- end

-- ministarRendering = {}

-- ministarRendering.changed = false
-- ministarRendering.defaultsLocation = "ministarRendering"

-- function ministarRendering.getSettings()
--   local defaults = root.assetJson("/v-defaultsettings.config:ministarRendering")
--   local cfg = player.getProperty("v-ministareffects-renderConfig", {})
--   cfg = sb.jsonMerge(defaults, cfg)
--   ministarRendering.populateSettings()
-- end

-- function ministarRendering.resetSettings()
--   local defaults = root.assetJson("/v-defaultsettings.config:ministarRendering")
--   ministarRendering.populateSettings(defaults)
-- end

-- function ministarRendering.populateSettings(cfg)
--   widget.setSelectedOption("ambientLightPrecision", cfg.lightIntervalIdx - 2)
--   widget.setChecked("btnAmbientLight", cfg.useLights)
--   widget.setChecked("btnPrettyRays", cfg.useImagesForRays)
--   widget.setChecked("btnLiquidParticles", cfg.useLiquidParticles)
-- end

-- function ministarRendering.applySettings()
--   local cfg = {
--     lightIntervalIdx = widget.getSelectedOption("ambientLightPrecision") + 2,
--     useLights = widget.getChecked("btnAmbientLight"),
--     useImagesForRays = widget.getChecked("btnPrettyRays"),
--     useLiquidParticles = widget.getChecked("btnLiquidParticles")
--   }
--   player.setProperty("v-ministareffects-renderConfig", cfg)
--   world.sendEntityMessage(player.id(), "v-ministareffects-applyRenderConfig", cfg)
-- end

function changeTab(newLayout)
  for _, layout in ipairs(layouts) do
    widget.setVisible(layout, false)
  end

  widget.setVisible(newLayout, true)
end

function updateSlider(name, value)
  widget.setSliderValue(name, value)

  local data = widget.getData(name)
  -- Update display widget as well if provided.
  if data and data.displayWidget then
    widget.setText(data.displayWidget, tostring(value))
  end
end