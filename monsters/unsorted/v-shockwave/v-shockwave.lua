require "/scripts/vec2.lua"
require "/scripts/set.lua"
require "/scripts/poly.lua"

require "/scripts/v-vec2.lua"
require "/scripts/v-world.lua"

require "/scripts/v-animator.lua"

-- Script for a damaging wave that propagates through a specific set of blocks.

local bufferTicks  -- Number of ticks for which to buffer

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
local lightningDensity

local area
local disappearTimer
local bufferTickTimer
local intangibleTimer

local previousBlocks
local blocks
local bufferedBlocks

local lightningBlocks
-- Similar in structure to an adjacency list in graph theory.
local animLightningBlocks
local expandWaveCalledWhileAnimLightningBlocksEmpty
local animLightningBlocksBack

local center
local hasStopped
local shouldDieVar

local nails

local lightning

function init()
  script.setUpdateDelta(1)
  bufferTicks = 3

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
  lightningDensity = config.getParameter("lightningDensity")

  monster.setAnimationParameter("ttl", disappearDelay)

  monster.setAnimationParameter("animationConfig", config.getParameter("animationConfig"))

  area = 0
  disappearTimer = disappearDelay
  bufferTickTimer = bufferTicks
  intangibleTimer = intangibleTime

  previousBlocks = {}

  blocks = {}  -- vec2 set
  vVec2.fSetInsert(blocks, {0, 0})
  lightningBlocks = {}  -- vec2 set
  vVec2.fSetInsert(lightningBlocks, {0, 0})

  bufferedBlocks = {}
  animLightningBlocksBack = {}
  animLightningBlocks = {}
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

  local lightningConfig = config.getParameter("lightningConfig")

  lightning = vAnimator.LightningController:new(
    lightningConfig,
    lightningConfig.startColor,
    lightningConfig.endColor,
    disappearDelay
  )

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

  -- lightning:update(dt)

  -- If no new blocks were found or the shockwave has spread far enough, disappear. Special case: nails are there and
  -- the shockwave just spawned.
  if area > maxArea or next(blocks) == nil then
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
    monster.setAnimationParameter("lightning", nil)

    return
  end

  -- Animation parameters seem to update at a rate much less than 60 times per second, so if this script updates
  -- faster than that, the wave appears broken without this code segment.
  bufferTickTimer = bufferTickTimer - 1

  if bufferTickTimer <= 0 then
    placeWave()
  end

  for blockStr, _ in pairs(blocks) do
    table.insert(bufferedBlocks, vVec2.fFromString(blockStr))
  end

  expandWave()
end

function expandWave()
  local nextBlocks = {}
  local nextLightningBlocks = {}

  for blockStr, _ in pairs(blocks) do
    local block = vVec2.fFromString(blockStr)

    for _, offset in ipairs(vWorld.ADJACENT_TILES) do
      local adjacent = vec2.add(block, offset)

      -- If the adjacent block is conductive and was not previously used...
      if not vVec2.fSetContains(previousBlocks, adjacent) and not vVec2.fSetContains(nextBlocks, adjacent)
          and containsConductive(vec2.add(center, adjacent)) then

        if math.random() < lightningDensity then
          if expandWaveCalledWhileAnimLightningBlocksEmpty then
            table.insert(animLightningBlocksBack, adjacent)
          end
          vVec2.fSetInsert(nextLightningBlocks, adjacent)

          -- Ignore blocks that are not connected to any other blocks.
          if vVec2.fSetContains(lightningBlocks, block) then
            if not animLightningBlocks[blockStr] then
              animLightningBlocks[blockStr] = {}
            end

            table.insert(animLightningBlocks[blockStr], adjacent)
          end
        end

        vVec2.fSetInsert(nextBlocks, adjacent)
        area = area + 1
      end
    end
  end

  expandWaveCalledWhileAnimLightningBlocksEmpty = false

  previousBlocks = blocks
  blocks = nextBlocks
  lightningBlocks = nextLightningBlocks
end

---Processes the wave so far.
function placeWave()
  -- monster.setAnimationParameter("nextBlocks", bufferedBlocks)

  local particleNextBlocks = {}
  local damageSources = {}
  -- Process bufferedBlocks. Adding of damage sources is deferred to the buffer to synchronize it with animation.
  for _, block in ipairs(bufferedBlocks) do
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
      table.insert(particleNextBlocks, block)
      triggerReceivers(blockPos)
    end
  end

  monster.setAnimationParameter("particleNextBlocks", particleNextBlocks)
  monster.setAnimationParameter("nextBlocks", particleNextBlocks)
  monster.setDamageSources(damageSources)

  bufferTickTimer = bufferTicks
  bufferedBlocks = {}

  -- Make animLightningBlocks skip `bufferTicks - 1` steps.
  local flattenedLightningBlocks = flatten(animLightningBlocks, animLightningBlocksBack)

  for blockStr, adjacentBlocks in pairs(flattenedLightningBlocks) do
    local block = vVec2.fFromString(blockStr)
    for _, adjacent in ipairs(adjacentBlocks) do
      lightning:add(vec2.add(center, block), vec2.add(center, adjacent))
    end
  end

  lightning:flush()

  animLightningBlocks = {}
  animLightningBlocksBack = {}
  expandWaveCalledWhileAnimLightningBlocksEmpty = true
end

function findEndBlocks(blocksMap, bl, out)
  local blStr = vVec2.fToString(bl)
  if not blocksMap[blStr] then return end
  for _, adjacent in ipairs(blocksMap[blStr]) do
    -- If the adjacent block has no neighbors...
    if not blocksMap[vVec2.fToString(adjacent)] then
      table.insert(out, adjacent)
    else
      findEndBlocks(blocksMap, adjacent, out)
    end
  end
end

function flatten(blocksMap, startBlocks)
  local flattened = {}
  for _, block in ipairs(startBlocks) do
    local blockStr = vVec2.fToString(block)
    flattened[blockStr] = {}
    findEndBlocks(blocksMap, block, flattened[blockStr])
  end

  return flattened
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
end

function isShockwave()
  return true
end