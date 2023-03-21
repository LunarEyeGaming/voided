ModProperty = {}

function ModProperty.update(position, layer)
  local layerLetter = layer == "foreground" and "F" or "B"
  world.debugText("9k%s", layerLetter, position, "green")
end