require "/scripts/vec2.lua"
require "/scripts/util.lua"

-- Script for poison that lingers on exposed blocks, with the radius getting smaller and smaller as time goes on.

local projectileType
local projectileParameters
local sourceEntity

local radius

local disappearTimer

local center
local shouldDieVar

function init()
  script.setUpdateDelta(1)

  projectileType = config.getParameter("projectileType", "v-shockwavedamage")
  projectileParameters = config.getParameter("projectileParameters", {})
  projectileParameters.power = config.getParameter("damage", 0) * root.evalFunction("monsterLevelPowerMultiplier", monster.level())
  projectileParameters.damageRepeatGroup = "v-lingeringpoison"
  projectileParameters.damageTeam = entity.damageTeam()

  -- Used so that monsters can target whoever fired a projectile that created a lingering damage region
  sourceEntity = config.getParameter("sourceEntity", entity.id())

  radius = config.getParameter("radius")  -- The radius of the damage
  -- the timeToLive of each projectile is the linger time of its corresponding region multiplied by the 
  -- damageTimeLingerTimeFactor.
  damageTimeLingerTimeFactor = config.getParameter("damageTimeLingerTimeFactor")
  minLingerTime = config.getParameter("minLingerTime")
  maxLingerTime = config.getParameter("maxLingerTime")

  monster.setAnimationParameter("ttl", maxLingerTime)
  monster.setAnimationParameter("animationConfig", config.getParameter("animationConfig"))

  disappearTimer = maxLingerTime

  local ownPos = mcontroller.position()

  -- Lock position to center of tile
  center = {math.floor(ownPos[1]) + 0.5, math.floor(ownPos[2]) + 0.5}
  mcontroller.setPosition(center)

  shouldDieVar = false

  message.setHandler("despawn", function()
    shouldDieVar = true
  end)

  monster.setDamageBar("None")

  tickTimer = 2

  -- placePoison()
end

function shouldDie()
  return shouldDieVar
end

function update(dt)
  -- For some weird reason, world.spawnProjectile has to be called on some update or else the projectiles won't deal any
  -- damage.
  if tickTimer then
    tickTimer = tickTimer - 1
    if tickTimer <= 0 then
      placePoison()
      tickTimer = nil
    end
  end
  disappearTimer = disappearTimer - dt
  if disappearTimer <= 0 then
    shouldDieVar = true
  end
end

-- Identifies where to put the poison and spawns projectiles there while also sending the blocks to the animation 
-- script.
function placePoison()
  local blocks = {}
  -- Place poison in a radial area, including only blocks that are exposed.
  for x = -radius, radius do
    for y = -radius, radius do
      local distance = vec2.mag({x, y})
      if distance <= radius then
        local blockPos = vec2.add(mcontroller.position(), {x, y})
        if isExposed(blockPos) and world.material(blockPos, "foreground") then
          -- timeToLive decreases as distance gets larger.
          local timeToLive = util.lerp(distance / radius, maxLingerTime, minLingerTime)

          local params = copy(projectileParameters)
          params.timeToLive = timeToLive * damageTimeLingerTimeFactor
          world.spawnProjectile(projectileType, blockPos, sourceEntity, {0, 0}, false, params)
          table.insert(blocks, {block = {x, y}, ttl = timeToLive})
        end
      end
    end
  end

  monster.setAnimationParameter("blocksId", 1)
  monster.setAnimationParameter("blocks", blocks)
end

function isExposed(position)
  -- Return true if any of the blocks adjacent to the given position are empty
  for _, offset in ipairs({{1, 0}, {0, 1}, {-1, 0}, {0, -1}}) do
    if not world.material(vec2.add(position, offset), "foreground") then
      return true
    end
  end

  return false
end

function isShockwave()
  return true
end