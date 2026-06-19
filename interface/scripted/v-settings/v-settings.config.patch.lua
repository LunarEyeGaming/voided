function patch(config)
  local label = config.gui.mechanics.children.lblUseSpecial2ForAimableDash
  label.value = label.value:gsub("%^blue;%[Special 2%]", "^green;[LShift]")
  if type(label.data) == "table" and label.data.tooltipText then
    label.data.tooltipText = label.data.tooltipText:gsub("%^blue;%[Special 2%]", "^green;[LShift]")
  end

  return config
end