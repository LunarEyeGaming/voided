ModProperty = {}

function ModProperty.update(position, layer)
  local layerLetter = layer == "foreground" and "F" or "B"
  world.debugText("9c%s", layerLetter, position, "green")
end

function ModProperty.destroy(position, layer)
  sb.logInfo("Script 9c: mod destroyed at %s, layer %s", position, layer)
end