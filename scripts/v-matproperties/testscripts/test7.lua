ModProperty = {}

function ModProperty.update(position, layer)
  world.debugText("Script 7, layer: %s", layer, position, "green")
  if  -- Syntax error
end

function ModProperty.destroy(position, layer)
  sb.logInfo("Script 7, mod destroyed at %s, layer %s", position, layer)
end