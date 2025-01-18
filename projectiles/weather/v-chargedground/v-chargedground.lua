require "/scripts/set.lua"
require "/scripts/vec2.lua"
require "/scripts/v-world.lua"

local conductiveMats
local conductiveMatMods

local sparkProjectileType
local effectQueryRadius
local effects

function init()
  local matAttributes = root.assetJson("/v-matattributes.config")
  conductiveMats = set.new(matAttributes.conductiveMaterials)
  conductiveMatMods = set.new(matAttributes.conductiveMatMods)

  sparkProjectileType = "v-voltitesparkfg"
  effectQueryRadius = 150
  effects = {"v-chargedground", "v-chargedgroundmessage"}

  script.setUpdateDelta(0)
end

function destroy()
  -- If the tile is conductive...
  if isConductive(vec2.add(mcontroller.position(), {0, -1})) then
    -- Spawn a spark effect at the current position on destruction.
    world.spawnProjectile(sparkProjectileType, mcontroller.position())
  end

  -- Apply status effects to nearby entities.
  local queried = world.entityQuery(mcontroller.position(), effectQueryRadius, {includedTypes = {"creature"}})
  for _, entityId in ipairs(queried) do
    for _, effectName in ipairs(effects) do
      vWorld.sendEntityMessage(entityId, "applyStatusEffect", effectName)
    end
  end
end

function isConductive(position)
  return set.contains(conductiveMats, world.material(position, "foreground"))
      or set.contains(conductiveMatMods, world.mod(position, "foreground"))
end