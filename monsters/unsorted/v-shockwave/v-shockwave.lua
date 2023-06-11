require "/scripts/vec2.lua"
require "/scripts/set.lua"

-- Script for a damaging wave that propagates through a specific set of blocks.

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

local area
local disappearTimer
local animTickTimer
local intangibleTimer

local previousBlocks
local nextBlocks
local animNextBlocks

local center
local shouldDieVar

local nails

function init()
  script.setUpdateDelta(1)
  animTicks = 3

  local matAttributes = root.assetJson("/v-matattributes.config")
  validMats = set.new(matAttributes.conductiveMaterials or {})
  validMatMods = set.new(matAttributes.conductiveMatMods or {})

  projectileType = config.getParameter("projectileType", "v-shockwavedamage")
  projectileParameters = config.getParameter("projectileParameters", {})
  projectileParameters.power = config.getParameter("damage", 0) * root.evalFunction("monsterLevelPowerMultiplier", monster.level())
  maxArea = config.getParameter("maxArea", 200)
  disappearDelay = config.getParameter("dissipationTime", 0.25)
  -- Used so that monsters can target whoever fired a projectile that created a shockwave
  sourceEntity = config.getParameter("sourceEntity", entity.id())
  nailDetectionRadius = config.getParameter("nailDetectionRadius", 1)
  intangibleTime = config.getParameter("intangibleTime", 0.1)  -- Amount of time before the shockwave actually begins.
  
  monster.setAnimationParameter("ttl", disappearDelay)
  
  monster.setAnimationParameter("animationConfig", config.getParameter("animationConfig"))

  area = 0
  disappearTimer = disappearDelay
  animTickTimer = animTicks
  intangibleTimer = intangibleTime
  
  previousBlocks = {}

  -- nextBlocks = {{0, 0}}
  nextBlocks = {}  -- vec2 set
  vec2SetInsert(nextBlocks, {0, 0})

  animNextBlocks = {}
  local ownPos = mcontroller.position()

  -- Lock position to center of tile
  center = {math.floor(ownPos[1]) + 0.5, math.floor(ownPos[2]) + 0.5}
  mcontroller.setPosition(center)
  
  shouldDieVar = false
  
  message.setHandler("despawn", function()
    shouldDieVar = true
  end)
  
  nails = {}  -- A map of nail entity IDs to their positions
  message.setHandler("v-noticeNail", function(_, _, nailId, position)
    nails[nailId] = position
  end)
  
  -- local myStr = vec2FToString(center)
  -- sb.logInfo("%s", myStr)
  -- --local myVec = vec2FFromString(myStr)
  -- vec2FFromString(myStr)
  
  monster.setDamageBar("None")
end

function shouldDie()
  return shouldDieVar
end

function update(dt)
  -- sb.logInfo("area: %s", area)
  -- If no new blocks were found or the shockwave has spread far enough, disappear. Special case: nails are there and
  -- the shockwave just spawned.
  --sb.logInfo("%s; %s", next(nextBlocks), nextBlocks)
  if intangibleTimer > 0 then
    intangibleTimer = intangibleTimer - dt
    return  -- Do nothing until the timer runs out
  end
  
  if area > maxArea or next(nextBlocks) == nil then
    disappearTimer = disappearTimer - dt
    if disappearTimer <= 0 then
      shouldDieVar = true
    end
    monster.setAnimationParameter("nextBlocks", nil)
    return
  end
  placeWave()
  expandWave()
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