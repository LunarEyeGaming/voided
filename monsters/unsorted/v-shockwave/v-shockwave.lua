require "/scripts/vec2.lua"
require "/scripts/set.lua"
require "/scripts/poly.lua"

require "/scripts/v-vec2.lua"
require "/scripts/v-world.lua"

-- Script for a damaging wave that propagates through a specific set of blocks.

local animTicks

local validMats
local validMatMods

local damage
local damageKind
local damagePoly
local damageTeam
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
local hasStopped
local shouldDieVar

local nails

function init()
  script.setUpdateDelta(1)
  animTicks = 3

  local matAttributes = root.assetJson("/v-matattributes.config")
  validMats = set.new(matAttributes.conductiveMaterials or {})
  validMatMods = set.new(matAttributes.conductiveMatMods or {})

  -- Used so that monsters can target whoever fired a projectile that created a shockwave
  sourceEntity = config.getParameter("sourceEntity", entity.id())

  damage = config.getParameter("damage", 0) * root.evalFunction("monsterLevelPowerMultiplier", monster.level())
  damageKind = config.getParameter("damageKind")
  damagePoly = config.getParameter("damagePoly")
  damageTeam = config.getParameter("damageTeamObj", world.entityDamageTeam(sourceEntity or entity.id()) or entity.damageTeam())
  damageType = config.getParameter("damageType")

  maxArea = config.getParameter("maxArea", 200)
  disappearDelay = config.getParameter("dissipationTime", 0.25)
  nailDetectionRadius = config.getParameter("nailDetectionRadius", 1)
  intangibleTime = config.getParameter("intangibleTime", 0.1)  -- Amount of time before the shockwave actually begins.

  monster.setAnimationParameter("ttl", disappearDelay)

  monster.setAnimationParameter("animationConfig", config.getParameter("animationConfig"))

  area = 0
  disappearTimer = disappearDelay
  animTickTimer = animTicks
  intangibleTimer = intangibleTime

  previousBlocks = {}

  nextBlocks = {}  -- vec2 set
  vVec2.fSetInsert(nextBlocks, {0, 0})

  animNextBlocks = {}
  local ownPos = mcontroller.position()

  -- Lock position to center of tile
  center = {math.floor(ownPos[1]) + 0.5, math.floor(ownPos[2]) + 0.5}
  mcontroller.setPosition(center)

  hasStopped = false
  shouldDieVar = false

  message.setHandler("despawn", function()
    shouldDieVar = true
  end)

  nails = {}  -- A map of nail entity IDs to their positions
  message.setHandler("v-noticeNail", function(_, _, nailId, position)
    nails[nailId] = position
  end)

  monster.setDamageBar("None")
end

function shouldDie()
  return shouldDieVar
end

function update(dt)
  if intangibleTimer > 0 then
    intangibleTimer = intangibleTimer - dt
    return  -- Do nothing until the timer runs out
  end

  -- If no new blocks were found or the shockwave has spread far enough, disappear. Special case: nails are there and
  -- the shockwave just spawned.
  if area > maxArea or next(nextBlocks) == nil then
    -- This code is executed immediately after the wave has stopped and not on subsequent ticks.
    if not hasStopped then
      placeWave()

      hasStopped = true
    end

    disappearTimer = disappearTimer - dt

    if disappearTimer <= 0 then
      shouldDieVar = true
    end

    monster.setAnimationParameter("nextBlocks", nil)
    monster.setAnimationParameter("particleNextBlocks", nil)

    return
  end

  -- Animation parameters seem to update at a rate much less than 60 times per second, so if this script updates
  -- faster than that, the wave appears broken without this code segment.
  animTickTimer = animTickTimer - 1

  if animTickTimer <= 0 then
    placeWave()
  end

  for blockStr, _ in pairs(nextBlocks) do
    table.insert(animNextBlocks, vVec2.fFromString(blockStr))
  end

  expandWave()
end

function expandWave()
  local temp = {}

  for blockStr, _ in pairs(nextBlocks) do
    for _, offset in ipairs(vWorld.ADJACENT_TILES) do
      local block = vVec2.fFromString(blockStr)
      local adjacent = vec2.add(block, offset)

      if not vVec2.fSetContains(previousBlocks, adjacent) and not vVec2.fSetContains(temp, adjacent)
          and containsConductive(vec2.add(center, adjacent)) then

        vVec2.fSetInsert(temp, adjacent)
        area = area + 1
      end
    end
  end

  previousBlocks = nextBlocks
  nextBlocks = temp
end

---Processes the wave so far.
function placeWave()
  monster.setAnimationParameter("nextBlocks", animNextBlocks)

  local particleNextBlocks = {}
  local damageSources = {}
  for _, block in ipairs(animNextBlocks) do
    local blockPos = vec2.add(center, block)

    if isExposed(blockPos) or containsCreature(blockPos) then
      table.insert(damageSources, {
        poly = poly.translate(damagePoly, block),
        damage = damage,
        damageSourceKind = damageKind,
        teamType = damageTeam.type,
        teamNumber = damageTeam.team,
        damageType = damageType,
        damageRepeatGroup = "v-shockwave",
        sourceEntityId = sourceEntity
      } --[[@as DamageSource]])
      -- world.spawnProjectile(projectileType, blockPos, sourceEntity, {0, 0}, false, projectileParameters)
      table.insert(particleNextBlocks, block)
      triggerReceivers(blockPos)
    end
  end

  monster.setAnimationParameter("particleNextBlocks", particleNextBlocks)
  monster.setDamageSources(damageSources)

  animTickTimer = animTicks
  animNextBlocks = {}
end

function isExposed(position)
  -- Return true if any of the blocks at or adjacent to the given position are empty
  for _, offset in ipairs({{0, 0}, {1, 0}, {0, 1}, {-1, 0}, {0, -1}}) do
    if not world.pointTileCollision(vec2.add(position, offset)) then
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

---Triggers objects that do something when a shockwave touches them.
---@param block any
function triggerReceivers(block)
  local queried = world.entityQuery(block, 1, {includedTypes = {"object"}, callScript = "v_onShockwaveReceived"})
  for _, entityId in ipairs(queried) do
    world.debugPoint(world.entityPosition(entityId), "green")
  end
end

function isShockwave()
  return true
end