require "/scripts/rect.lua"
require "/scripts/util.lua"

local forceRegions

function init()
  util.setDebug(true)
  forceRegions = config.getParameter("forceRegions")
end

function update(dt)
  local forceRegionsCopy = copy(forceRegions)
  for _, region in ipairs(forceRegionsCopy) do
    if region.rectRegion then
      region.rectRegion = rect.translate(region.rectRegion, mcontroller.position())
      util.debugRect(region.rectRegion, "blue")
    end
  end
  monster.setPhysicsForces(forceRegionsCopy)
end

function shouldDie()
  return status.resourcePercentage("health") <= 0.0
end