require "/scripts/vec2.lua"

-- Script for a damaging wave that propagates through a specific set of blocks.

function init()
  script.setUpdateDelta(1)
  self.animTicks = 3

  self.validMats = config.getParameter("validMats")
  self.projectileType = config.getParameter("projectileType", "v-shockwavedamage")
  self.projectileParameters = config.getParameter("projectileParameters", {})
  self.projectileParameters.power = config.getParameter("damage", 0) * root.evalFunction("monsterLevelPowerMultiplier", monster.level())
  self.maxArea = config.getParameter("maxArea", 200)
  self.disappearDelay = config.getParameter("dissipationTime", 0.25)
  
  monster.setAnimationParameter("ttl", self.disappearDelay)
  
  monster.setAnimationParameter("animationConfig", config.getParameter("animationConfig"))

  self.area = 0
  self.disappearTimer = self.disappearDelay
  self.animTickTimer = self.animTicks
  
  self.previousBlocks = {}
  self.nextBlocks = {{0, 0}}
  self.animNextBlocks = {}
  local ownPos = mcontroller.position()
  self.center = {math.floor(ownPos[1]) + 0.5, math.floor(ownPos[2]) + 0.5}
  mcontroller.setPosition(self.center)
  
  self.shouldDie = false
  
  message.setHandler("despawn", function()
    self.shouldDie = true
  end)
  
  monster.setDamageBar("None")
end

function shouldDie()
  return self.shouldDie
end

function update(dt)
  -- sb.logInfo("area: %s", self.area)
  if self.area > self.maxArea or next(self.nextBlocks) == nil then
    self.disappearTimer = self.disappearTimer - dt
    if self.disappearTimer <= 0 then
      self.shouldDie = true
    end
    monster.setAnimationParameter("nextBlocks", nil)
    return
  end
  placeWave()
  expandWave()
end

function expandWave()
  --sb.logInfo("nextBlocks: %s", self.nextBlocks)
  --sb.logInfo("previousBlocks: %s", self.previousBlocks)
  local temp = {}
  for _, block in ipairs(self.nextBlocks) do
    for _, offset in ipairs({{1, 0}, {0, 1}, {-1, 0}, {0, -1}}) do
      local adjacent = vec2.add(block, offset)
      if not includesVec2(self.previousBlocks, adjacent) and not includesVec2(temp, adjacent) and includes(self.validMats, world.material(vec2.add(self.center, adjacent), "foreground")) then
        table.insert(temp, adjacent)
        self.area = self.area + 1
      end
    end
  end
  self.previousBlocks = self.nextBlocks
  self.nextBlocks = temp
end

function placeWave()
  -- Animation parameters seem to update at a rate much less than 60 times per second, so if this script updates
  -- faster than that, the wave appears broken without this code segment.
  self.animTickTimer = self.animTickTimer - 1
  if self.animTickTimer <= 0 then
    monster.setAnimationParameter("nextBlocks", self.animNextBlocks)
    self.animTickTimer = self.animTicks
    self.animNextBlocks = {}
  end
  for _, block in ipairs(self.nextBlocks) do
    if isExposed(vec2.add(self.center, block)) then
      world.spawnProjectile(self.projectileType, vec2.add(self.center, block), entity.id(), {0, 0}, false, self.projectileParameters)
    end
    table.insert(self.animNextBlocks, block)
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