require "/scripts/vec2.lua"

local material
local outerMaterial
local points
local outerPoints

function init()
  local radius = config.getParameter("radius")
  material = config.getParameter("material")
  outerMaterial = config.getParameter("outerMaterial", material)
  -- Generate a list of points in a circle.
  points = {}
  outerPoints = {}
  for x = -radius, radius do
    for y = -radius, radius do
      local point = {x, y}
      local mag = vec2.mag(point)
      if mag <= radius - 1 then
        table.insert(points, {pos = point, mag = mag})
      elseif radius - 1 < mag and mag <= radius then
        table.insert(outerPoints, {pos = point, mag = mag})
      end
    end
  end

  -- Sort the points by mag
  table.sort(points, function(p1, p2)
    return p1.mag < p2.mag
  end)

  projectile.setTimeToLive(script.updateDt() * 4 * radius)  -- Necessary in the case of remote connections.
end

function update()
  -- Place the materials
  local ownPos = mcontroller.position()
  for _, point in ipairs(points) do
    world.placeMaterial(vec2.add(ownPos, point.pos), "foreground", material, nil, false)
    world.placeMaterial(vec2.add(ownPos, point.pos), "background", material, nil, false)
  end
  for _, point in ipairs(outerPoints) do
    world.placeMaterial(vec2.add(ownPos, point.pos), "foreground", outerMaterial, nil, false)
    world.placeMaterial(vec2.add(ownPos, point.pos), "background", outerMaterial, nil, false)
  end
end