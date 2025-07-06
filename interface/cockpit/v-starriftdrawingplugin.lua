local riftDrawable
local starSize

local oldInit = init or function() end
local oldView_renderSystem = View.renderSystem or function() end
local oldView_renderPlanet = View.renderPlanet or function() end

function init()
  oldInit()

  riftDrawable = config.getParameter("v-starRiftDrawable")
  starSize = root.assetJson("/systemworld.config:starSize")
end

function View:renderSystem(args, dt)
  if not self.planet.planet then
    self:v_drawStarRift(args.system)
  end

  oldView_renderSystem(self, args, dt)
end

function View:renderPlanet(args)
  self:v_drawStarRift(coordinateSystem(args.planet))

  oldView_renderPlanet(self, args)
end

function View:v_drawStarRift(system)
  if v_targetInEDSystem(system) then
    local scale = riftDrawable.scale * starSize * View.systemCamera.scale
    local opacity = 1.0
    local color = {255, 255, 255, opacity * 255}
    View.canvas:drawImage(riftDrawable.image, self:sToScreen({0, 0}), scale, color, true)
  end

  if not system then
    world.debugText("System not found", {1078, 1026}, "green")
  end
end

---Returns `true` if the target is (for certain) in an Outsider Star system and `false` otherwise.
---@param target CelestialCoordinate
---@return boolean
function v_targetInEDSystem(target)
  if not target then
    return false
  end

  local currentSystemParams = celestial.planetParameters(target)
  return currentSystemParams and currentSystemParams.typeName == "v-extradimensional"
end