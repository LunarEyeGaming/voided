require "/scripts/v-animator.lua"

LiquidGunAltAbility = WeaponAbility:new()

function LiquidGunAltAbility:init()
  self.active = false
end

function LiquidGunAltAbility:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)

  if self.fireMode == (self.activatingFireMode or self.abilitySlot)
    and not self.weapon.currentAbility then

    self:setState(self.collectingState)
  end
end

function LiquidGunAltAbility:collectingState()
  local collectTimer = self.collectInterval

  self:activate()

  while self.fireMode == (self.activatingFireMode or self.abilitySlot) and status.overConsumeResource("energy", (self.energyUsage or 0) * self.dt) do
    -- Periodically collect liquid.
    collectTimer = collectTimer - self.dt
    if collectTimer <= 0 then
      self:collectLiquid(activeItem.ownerAimPosition(), self.collectRadius)

      collectTimer = self.collectInterval
    end

    coroutine.yield()
  end

  self:deactivate()
end

function LiquidGunAltAbility:collectLiquid(position, radius)
  -- if world.lineCollision(mcontroller.position(), position) then return end

  if world.magnitude(mcontroller.position(), position) > self.maxCollectRange then return end

  if radius and radius > 0 then
    for x = -radius, radius do
      for y = -radius, radius do
        local offset = {x, y}
        if vec2.mag(offset) <= radius then
          local pos = vec2.add(position, offset)
          self:collectOneLiquid(pos)
        end
      end
    end
  else
    self:collectOneLiquid(position)
  end
end

function LiquidGunAltAbility:collectOneLiquid(position)
  local liquid = world.liquidAt(position)

  if world.isTileProtected(position) then
    return
  end

  -- Don't collect if there isn't enough liquid.
  if not liquid or liquid[2] < self.collectThreshold then
    return
  end

  local liquidConfig = root.liquidConfig(liquid[1])

  -- Don't collect if the liquid isn't real or it doesn't have an item.
  if not liquidConfig or not liquidConfig.config.itemDrop then return end

  -- Consume some liquid, putting any leftover liquid back.
  local consumedLiquid = world.destroyLiquid(position)
  if consumedLiquid and consumedLiquid[2] > 1 then
    world.spawnLiquid(position, consumedLiquid[1], consumedLiquid[2] - 1)
  end

  -- Give the liquid to the player.
  player.giveItem(liquidConfig.config.itemDrop)
end

function LiquidGunAltAbility:activate()
  self.active = true
  animator.playSound("fireStart")
  animator.playSound("fireLoop", -1)
end

function LiquidGunAltAbility:deactivate()
  self.active = false
  animator.stopAllSounds("fireStart")
  animator.stopAllSounds("fireLoop")
  animator.playSound("fireEnd")
end

function LiquidGunAltAbility:uninit()
end