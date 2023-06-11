require "/scripts/util.lua"
require "/scripts/vec2.lua"
require "/scripts/rect.lua"

local loadRegion

function init()
  loadRegion = rect.translate(config.getParameter("loadArea"), config.getParameter("loadPosition"))
end

function update(dt)
  world.loadRegion(loadRegion)
end