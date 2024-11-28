require "/scripts/set.lua"
require "/scripts/vec2.lua"

local conductiveMats
local conductiveMatMods

function init()
  local matAttributes = root.assetJson("/v-matattributes.config")
  conductiveMats = set.new(matAttributes.conductiveMaterials)
  conductiveMatMods = set.new(matAttributes.conductiveMatMods)
end

function destroy()
  if isConductive(vec2.add(mcontroller.position(), {0, -1})) then
    world.spawnProjectile("v-voltitesparkfg", mcontroller.position())
  end
end

function isConductive(position)
  return set.contains(conductiveMats, world.material(position, "foreground"))
      or set.contains(conductiveMatMods, world.mod(position, "foreground"))
end