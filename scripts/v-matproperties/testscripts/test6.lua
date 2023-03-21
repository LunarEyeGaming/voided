BadName = {}

function BadName.update(position, layer)
  world.debugText("Script 6, layer: %s", layer, position, "green")
end

function BadName.destroy(position, layer)
  sb.logInfo("Script 6, mod destroyed at %s, layer %s", position, layer)
end