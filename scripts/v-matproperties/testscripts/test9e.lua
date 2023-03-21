ModProperty = {}

function ModProperty.update(position, layer)
  local layerLetter = layer == "foreground" and "F" or "B"
  world.debugText("9e%s", layerLetter, position, "green")
end

function ModProperty.destroy(position, layer)
  sb.logInfo("Script 9e: mod destroyed at %s, layer %s", position, layer)
end