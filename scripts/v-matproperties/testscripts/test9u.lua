ModProperty = {}

function ModProperty.update(position, layer)
  local layerLetter = layer == "foreground" and "F" or "B"
  world.debugText("9u%s", layerLetter, position, "green")
  local myVar = nil
  local myOtherVar = 50 + myVar  -- Runtime error
end

function ModProperty.destroy(position, layer)
  sb.logInfo("Script 9u, mod destroyed at %s, layer %s", position, layer)
  myFunc()
end