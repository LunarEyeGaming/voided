require "/scripts/set.lua"
require "/scripts/statuseffects/v-tickdamage.lua"
require "/scripts/rect.lua"

local conductiveMats
local conductiveMatMods

local damage
local tickTime

local tickDamage

function init()
  local matAttributes = root.assetJson("/v-matattributes.config")
  conductiveMats = set.new(matAttributes.conductiveMaterials)
  conductiveMatMods = set.new(matAttributes.conductiveMatMods)

  local boundBox = mcontroller.boundBox()
  animator.setParticleEmitterOffsetRegion("sparks", {boundBox[1], boundBox[2], boundBox[3], boundBox[2]})

  damage = config.getParameter("damage")
  tickTime = config.getParameter("tickTime")

  tickDamage = VTickDamage:new{ kind = "electric", amount = damage, damageType = "IgnoresDef", interval = tickTime }
end

function update(dt)
  -- If conductive tiles are below the player...
  if touchingConductiveGround() then
    -- Activate particle emitter.
    animator.setParticleEmitterActive("sparks", true)
    -- If grace period is not active...
    if not status.statPositive("v-chargedgroundGraceStat") then
      -- Run tick damage
      tickDamage:update(dt)
    end
  else
    -- Deactivate particle emitter.
    animator.setParticleEmitterActive("sparks", false)
    -- Reset tick damage.
    tickDamage:reset()
  end
end

function touchingConductiveGround()
  -- If any tile below the bounding box is conductive, then return true. Otherwise, return false.
  local boundBox = rect.translate(mcontroller.boundBox(), mcontroller.position())
  local y = boundBox[2] - 1

  for x = boundBox[1], boundBox[3] do
    if isConductive({ x, y }) then
      return true
    end
  end

  return false
end

function isConductive(position)
  return set.contains(conductiveMats, world.material(position, "foreground"))
      or set.contains(conductiveMatMods, world.mod(position, "foreground"))
end