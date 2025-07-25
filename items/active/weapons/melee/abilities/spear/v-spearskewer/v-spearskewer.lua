require "/items/active/weapons/melee/abilities/spear/spearstab.lua"
require "/scripts/vec2.lua"
require "/scripts/status.lua"
require "/scripts/util.lua"

-- Spear stab attack
-- Extends normal spear attack and adds an ability to skewer monsters
SpearSkewer = SpearStab:new()

function SpearSkewer:init()
  SpearStab.init(self)

  -- Add "v-spearskewer" as a status effect (which keeps hit entities on the spear), if it is not already there.
  if self.holdDamageConfig.statusEffects then
    if not contains(self.holdDamageConfig.statusEffects, "v-spearskewer") then
      table.insert(self.holdDamageConfig.statusEffects, "v-spearskewer")
    end
  else
    self.holdDamageConfig.statusEffects = {"v-spearskewer"}
  end

  self.skewedEntities = {}

  self.damageListener = damageListener("inflictedHits", function(notifications)
    -- For each notification...
    for _, notification in ipairs(notifications) do
      -- If the target entity exists...
      if world.entityExists(notification.targetEntityId) then
        table.insert(self.skewedEntities, notification.targetEntityId)
      end
    end
  end)
end

function SpearSkewer:update(dt, fireMode, shiftHeld)
  SpearStab.update(self, dt, fireMode, shiftHeld)

  self.damageListener:update()
end

-- Override
function SpearSkewer:hold()
  self.weapon:setStance(self.stances.hold)
  self.weapon:updateAim()

  local prevPos

  while self.fireMode == "primary" do
    local damageArea = partDamageArea("blade")
    self.weapon:setDamage(self.holdDamageConfig, damageArea)

    prevPos = self:updateSkewered(prevPos)

    coroutine.yield()
  end

  -- For each skewered entity...
  for _, skewedId in ipairs(self.skewedEntities) do
    -- If the entity exists...
    if world.entityExists(skewedId) then
      -- Release the entity.
      world.sendEntityMessage(skewedId, "v-spearskewer-release")
    end
  end

  self.cooldownTimer = self:cooldownTime()
end

function SpearSkewer:updateSkewered(prevPos)
  -- Calculate the new position to set for each skewered entity.
  local newPos = activeItem.handPosition(animator.partPoint("blade", "damageCenter"))

  -- If the new position is not the same as the previous position...
  if (not prevPos or not vec2.eq(prevPos, newPos)) then
    world.debugPoint(vec2.add(mcontroller.position(), newPos), "green")
    -- For each skewered entity (iterated through backwards)...
    for i = #self.skewedEntities, 1, -1 do
      local skewedId = self.skewedEntities[i]

      -- If the entity exists...
      if world.entityExists(skewedId) then
        -- Update its position.
        world.sendEntityMessage(skewedId, "v-spearskewer-updatePos", newPos, self.holdDamageConfig.knockback, entity.id())
      else
        table.remove(self.skewedEntities, i)
      end
    end
  end

  return newPos
end
