require "/scripts/v-util.lua"

function init()
  getSettings()
end

function update(dt)
end

function dismissed()
end

function ambientLightPrecision()
end

function btnAmbientLight()
end

function btnPrettyRays()
end

function btnApply()
  applySettings()
end

function btnCancel()
  pane.dismiss()
end

function getSettings()
  local cfg = player.getProperty("v-ministareffects-renderConfig")
  if cfg then
    widget.setSelectedOption("ambientLightPrecision", cfg.lightIntervalIdx - 2)
    widget.setChecked("btnAmbientLight", cfg.useLights)
    widget.setChecked("btnPrettyRays", cfg.useImagesForRays)
  end
end

function applySettings()
  local cfg = {
    lightIntervalIdx = widget.getSelectedOption("ambientLightPrecision") + 2,
    useLights = widget.getChecked("btnAmbientLight"),
    useImagesForRays = widget.getChecked("btnPrettyRays")
  }
  player.setProperty("v-ministareffects-renderConfig", cfg)
  world.sendEntityMessage(player.id(), "v-ministareffects-applyRenderConfig", cfg)
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