ModProperty = {}

function ModProperty.update(position, layer)
  local layerLetter = layer == "foreground" and "F" or "B"
  world.debugText("2%s", layerLetter, position, "green")
end

function ModProperty.destroy(position, layer)
  local layerLetter = layer == "foreground" and "F" or "B"
  world.debugText("2%s D", layerLetter, position, "green")
end