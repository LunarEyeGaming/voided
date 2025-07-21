require "/scripts/vec2.lua"

function init()
end

function destroy()

  -- Place the materials
  local material = config.getParameter("material")

  local ownPos = mcontroller.position()
  world.placeObject("terra_placeassist", ownPos --[[@as Vec2I]], nil, {
    material = material,
    overlap = true,
    layer = "foreground"
  })
  world.spawnProjectile("v-ice19bombblockgen", ownPos, nil, nil, nil, {
    material = material,
    outerMaterial = config.getParameter("outerMaterial"),
    radius = config.getParameter("radius")
  })
end