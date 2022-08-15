require "/scripts/vec2.lua"

-- Script for a damaging wave that propagates through a specific set of blocks.

local animTicks
local validMats
local validMatMods
local projectileType
local projectileParameters
local maxArea
local disappearDelay
local area
local disappearTimer
local animTickTimer
local previousBlocks
local nextBlocks
local animNextBlocks
local center
local shouldDieVar

function init()
  script.setUpdateDelta(1)
  animTicks = 3

  local matAttributes = root.assetJson("/v-matattributes.config")
  
  validMats = matAttributes.conductiveMaterials
  validMatMods = matAttributes.conductiveMatMods
  projectileType = config.getParameter("projectileType", "v-shockwavedamage")
  projectileParameters = config.getParameter("projectileParameters", {})
  projectileParameters.power = config.getParameter("damage", 0) * root.evalFunction("monsterLevelPowerMultiplier", monster.level())
  maxArea = config.getParameter("maxArea", 200)
  disappearDelay = config.getParameter("dissipationTime", 0.25)
  
  monster.setAnimationParameter("ttl", disappearDelay)
  
  monster.setAnimationParameter("animationConfig", config.getParameter("animationConfig"))

  area = 0
  disappearTimer = disappearDelay
  animTickTimer = animTicks
  
  previousBlocks = {}
  nextBlocks = {{0, 0}}
  animNextBlocks = {}
  local ownPos = mcontroller.position()
  center = {math.floor(ownPos[1]) + 0.5, math.floor(ownPos[2]) + 0.5}
  mcontroller.setPosition(center)
  
  shouldDieVar = false
  
  message.setHandler("despawn", function()
    shouldDieVar = true
  end)
  
  monster.setDamageBar("None")
end

function shouldDie()
  return shouldDieVar
end

function update(dt)
  -- sb.logInfo("area: %s", area)
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
  for _, block in ipairs(nextBlocks) do
    for _, offset in ipairs({{1, 0}, {0, 1}, {-1, 0}, {0, -1}}) do
      local adjacent = vec2.add(block, offset)
      if not includesVec2(previousBlocks, adjacent) and not includesVec2(temp, adjacent) 
        and (includes(validMats, world.material(vec2.add(center, adjacent), "foreground"))
        or includes(validMatMods, world.mod(vec2.add(center, adjacent), "foreground"))) then

        table.insert(temp, adjacent)
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
      if isExposed(vec2.add(center, block)) then
        world.spawnProjectile(projectileType, vec2.add(center, block), entity.id(), {0, 0}, false, projectileParameters)
      end
    end
    animTickTimer = animTicks
    animNextBlocks = {}
  end
  for _, block in ipairs(nextBlocks) do
    table.insert(animNextBlocks, block)
  end
end

-- Made with vec2 comparisons in mind
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

function isExposed(position)
  -- Return true if any of the blocks adjacent to the given position are empty
  for _, offset in ipairs({{1, 0}, {0, 1}, {-1, 0}, {0, -1}}) do
    if not world.material(vec2.add(position, offset), "foreground") then
      return true
    end
  end
  
  return false
end