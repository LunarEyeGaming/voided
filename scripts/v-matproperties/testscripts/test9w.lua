ModProperty = {}

function ModProperty.update(position, layer)
  local layerLetter = layer == "foreground" and "F" or "B"
  world.debugText("9w%s", layerLetter, position, "green")
  
  if  -- Syntax error
end

function ModProperty.destroy(position, layer)
  sb.logInfo("Script 9w, mod destroyed at %s, layer %s", position, layer)
end