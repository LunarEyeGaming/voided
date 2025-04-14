require "/scripts/vec2.lua"

local radius
local material

function init()
  radius = config.getParameter("radius")
  material = config.getParameter("material")
end

function destroy()
  -- -- Generate a list of points in a circle.
  -- local points = {}
  -- for x = -radius, radius do
  --   for y = -radius, radius do
  --     local point = {x, y}
  --     local mag = vec2.mag(point)
  --     if mag <= radius then
  --       table.insert(points, {pos = point, mag = mag})
  --     end
  --   end
  -- end

  -- -- Sort the points by mag
  -- table.sort(points, function(p1, p2)
  --   return p1.mag < p2.mag
  -- end)

  -- Place the materials
  local ownPos = mcontroller.position()
  world.placeObject("terra_placeassist", ownPos --[[@as Vec2I]], nil, {
    material = material,
    overlap = true,
    layer = "foreground"
  })
  -- for _, point in ipairs(points) do
  --   world.placeMaterial(vec2.add(ownPos, point.pos), "foreground", material, nil, true)
  -- end
  world.spawnProjectile("v-ice19bombblockgen", ownPos, nil, nil, nil, {
    material = material,
    radius = radius
  })
end