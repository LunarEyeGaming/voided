ModProperty = {}

function ModProperty.update(position, layer)
  local layerLetter = layer == "foreground" and "F" or "B"
  world.debugText("9v%s", layerLetter, position, "green")
  local myVar = nil
  local myOtherVar = 50 + myVar  -- Runtime error
end

function ModProperty.destroy(position, layer)
  sb.logInfo("Script 9v, mod destroyed at %s, layer %s", position, layer)
  myFunc()
end