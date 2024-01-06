require "/scripts/vec2.lua"
require "/scripts/util.lua"

-- Script for poison that lingers on exposed blocks, with the radius getting smaller and smaller as time goes on.

local animTicks

local validMats
local validMatMods

local projectileType
local projectileParameters
local maxArea
local disappearDelay
local sourceEntity
local nailDetectionRadius
local intangibleTime

local radius

local area
local disappearTimer
local animTickTimer
local intangibleTimer

local previousBlocks
local nextBlocks
local animNextBlocks

local center
local shouldDieVar

local shouldPlacePoison

function init()
  script.setUpdateDelta(1)
  animTicks = 3

  projectileType = config.getParameter("projectileType", "v-shockwavedamage")
  projectileParameters = config.getParameter("projectileParameters", {})
  projectileParameters.power = config.getParameter("damage", 0) * root.evalFunction("monsterLevelPowerMultiplier", monster.level())
  projectileParameters.damageRepeatGroup = "v-lingeringpoison"
  
  maxArea = config.getParameter("maxArea", 200)
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

  area = 0
  disappearTimer = maxLingerTime
  animTickTimer = animTicks
  intangibleTimer = intangibleTime

  local ownPos = mcontroller.position()

  -- Lock position to center of tile
  center = {math.floor(ownPos[1]) + 0.5, math.floor(ownPos[2]) + 0.5}
  mcontroller.setPosition(center)
  
  shouldDieVar = false
  
  message.setHandler("despawn", function()
    shouldDieVar = true
  end)
  
  monster.setDamageBar("None")
  
  shouldPlacePoison = false
  
  -- placePoison()
end

function shouldDie()
  return shouldDieVar
end

function update(dt)
  -- For some weird reason, world.spawnProjectile has to be called on update or else the projectiles won't deal any
  -- damage.
  if not shouldPlacePoison then
    placePoison()
    shouldPlacePoison = true
  end
  disappearTimer = disappearTimer - dt
  if disappearTimer <= 0 then
    shouldDieVar = true
  end

  animTickTimer = animTickTimer - 1
  if animTickTimer <= 0 then
    monster.setAnimationParameter("blocks", nil)
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

  monster.setAnimationParameter("blocks", blocks)
end

function expandWave()
  --sb.logInfo("nextBlocks: %s", nextBlocks)
  --sb.logInfo("previousBlocks: %s", previousBlocks)
  local temp = {}
  -- for _, block in ipairs(nextBlocks) do
  for blockStr, _ in pairs(nextBlocks) do
    for _, offset in ipairs({{1, 0}, {0, 1}, {-1, 0}, {0, -1}}) do
      local block = vec2FFromString(blockStr)
      --sb.logInfo("blockStr: %s", blockStr)
      --sb.logInfo("block: %s", block)
      local adjacent = vec2.add(block, offset)
      -- if not includesVec2(previousBlocks, adjacent) and not includesVec2(temp, adjacent) 
        -- and (includes(validMats, world.material(vec2.add(center, adjacent), "foreground"))
        -- or includes(validMatMods, world.mod(vec2.add(center, adjacent), "foreground"))) then
      --sb.logInfo("previousBlocks Contains?: %s", vec2SetContains(previousBlocks, adjacent))
      --sb.logInfo("temp Contains?: %s", vec2SetContains(temp, adjacent))
      if not vec2SetContains(previousBlocks, adjacent) and not vec2SetContains(temp, adjacent) 
          and containsConductive(vec2.add(center, adjacent)) then

        -- table.insert(temp, adjacent)
        vec2SetInsert(temp, adjacent)
        area = area + 1
      end
    end
  end
  previousBlocks = nextBlocks
  nextBlocks = temp
end

function placeWave()
  -- Animation parameters seem to update at a rate much less than 60 times per second, so if this script updates
  -- faster than that, the wave appears broken without this code segment.
  animTickTimer = animTickTimer - 1
  if animTickTimer <= 0 then
    monster.setAnimationParameter("nextBlocks", animNextBlocks)
    for _, block in ipairs(animNextBlocks) do
      local blockPos = vec2.add(center, block)
      if isExposed(blockPos) or containsCreature(blockPos) then
        world.spawnProjectile(projectileType, blockPos, sourceEntity, {0, 0}, false, projectileParameters)
      end
    end
    animTickTimer = animTicks
    animNextBlocks = {}
  end
  -- for _, block in ipairs(nextBlocks) do
    -- table.insert(animNextBlocks, block)
  for blockStr, _ in pairs(nextBlocks) do
    --sb.logInfo("%s", blockStr)
    table.insert(animNextBlocks, vec2FFromString(blockStr))
  end
end

-- Made with vec2 comparisons in mind
-- Returns whether or not a table includes a vec2
function includesVec2(t, v)
  for _, tv in ipairs(t) do
    if vec2.eq(tv, v) then
      return true
    end
  end
  
  return false
end

function includes(t, v)
  for _, tv in ipairs(t) do
    if tv == v then
      return true
    end
  end
  
  return false
end

-- Returns a string representation of a Vec2F to be used for hash lookups.
function vec2FToString(vector)
  return string.format("%f,%f", vector[1], vector[2])
end

-- Returns a Vec2F from a string.
function vec2FFromString(str)
  -- Extract the strings containing the entries of the stringified Vec2F (which can be positive or negative)
  local xStr, yStr = string.match(str, "(%-?%d+%.%d+),(%-?%d+%.%d+)")

  return {tonumber(xStr), tonumber(yStr)}
end

-- Inserts a Vec2F into a set.
function vec2SetInsert(set, vector)
  local strVec = vec2FToString(vector)
  
  set[strVec] = true
end

-- Returns whether or not the given vector is in the given set (true if so and nil if not).
function vec2SetContains(set, vector)
  local strVec = vec2FToString(vector)
  
  return set[strVec]
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

function containsCreature(position)
  -- Return true if the area within a one-block radius of the given position contains at least one entity that matches
  -- the "creature" type.
  
  return #world.entityQuery(position, 1, {includedTypes = {"creature"}}) > 0
end

-- Returns whether or not the given tile has at least one nail embedded into it.
function hasNails(position)
  if not world.pointCollision(position) then
    return false
  end

  for nailId, nailPos in pairs(nails) do
    if world.entityExists(nailId) and world.magnitude(position, nailPos) <= nailDetectionRadius then
      return true
    end
  end
  
  return false
end

-- Returns whether or not the given tile has a conductive material or matmod, or the tile has nails.
function containsConductive(position)
  return set.contains(validMats, world.material(position, "foreground"))
      or set.contains(validMatMods, world.mod(position, "foreground")) or hasNails(position)
end

function isShockwave()
  return true
end