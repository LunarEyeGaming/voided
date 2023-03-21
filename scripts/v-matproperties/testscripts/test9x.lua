ModProperty = {}

function ModProperty.update(position, layer)
  local layerLetter = layer == "foreground" and "F" or "B"
  world.debugText("9x%s", layerLetter, position, "green")
  
  if  -- Syntax error
end

function ModProperty.destroy(position, layer)
  sb.logInfo("Script 9x, mod destroyed at %s, layer %s", position, layer)
end