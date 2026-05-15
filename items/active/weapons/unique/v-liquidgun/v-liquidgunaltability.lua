require "/scripts/v-animator.lua"

LiquidGunAltAbility = WeaponAbility:new()

function LiquidGunAltAbility:init()
  -- sb.logInfo("Initializing alt ability")
  self.active = false

  activeItem.setScriptedAnimationParameter("emissionInterval", self.suctionEmissionInterval)
  activeItem.setScriptedAnimationParameter("emissionFuzzAngle", self.suctionEmissionFuzzAngle)
  activeItem.setScriptedAnimationParameter("emissionDistance", self.suctionEmissionDistance)
  activeItem.setScriptedAnimationParameter("suctionParticle", self.suctionParticle)

  -- sb.logInfo("Finished initializing alt ability")
end

function LiquidGunAltAbility:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)

  if self.fireMode == (self.activatingFireMode or self.abilitySlot)
    and not self.weapon.currentAbility then

    self:setState(self.collectingState)
  end

  activeItem.setScriptedAnimationParameter("firePosition", self:firePosition())
  local angle = self.weapon.aimAngle
  if self.weapon.aimDirection < 0 then
    angle = math.pi - angle
  end
  activeItem.setScriptedAnimationParameter("fireAngle", angle)
end

function LiquidGunAltAbility:collectingState()
  local collectTimer = self.collectInterval

  self:activate()

  while self.fireMode == (self.activatingFireMode or self.abilitySlot) and status.overConsumeResource("energy", (self.energyUsage or 0) * self.dt) do
    -- Periodically collect liquid.
    collectTimer = collectTimer - self.dt
    if collectTimer <= 0 then
      -- -- Perform a raycast for tile collision or liquid. If both fail, use the aim position directly.
      -- local collidePoint

      -- collidePoint = world.lineCollision(self:firePosition(), activeItem.ownerAimPosition())

      -- if not collidePoint then
      --   local collideLiquidPoints = world.liquidAlongLine(self:firePosition(), activeItem.ownerAimPosition())

      --   if #collideLiquidPoints > 0 then
      --     collidePoint = collideLiquidPoints[1][1]
      --   else
      --     collidePoint = activeItem.ownerAimPosition()
      --   end
      -- end

      -- world.debugPoint(collidePoint, "magenta")
      -- self:collectLiquid(collidePoint, self.collectRadius)
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
    local tiles = self:spacesToCollect(position, radius)

    local partition = self:partitionLiquids(tiles)

    local liquidWasCollected = false
    for name, positionsAndQuantities in pairs(partition) do
      local amountCollected = self:collectLiquidsAtTiles(positionsAndQuantities)
      if amountCollected > 0 then
        liquidWasCollected = true
      end

      player.giveItem({name = name, count = amountCollected})
    end

    if liquidWasCollected then
      animator.playSound("collect")
    end
  else
    self:collectOneLiquid(position)
  end
end

---Returns a list of positions within a circle centered at `position` with radius `radius`.
---@param position Vec2F
---@param radius number
---@return Vec2F[]
function LiquidGunAltAbility:spacesToCollect(position, radius)
  local positions = {}
  for x = -radius, radius do
    for y = -radius, radius do
      local offset = {x, y}
      if vec2.mag(offset) <= radius then
        table.insert(positions, vec2.add(position, offset))
      end
    end
  end

  return positions
end

---Returns the names of the liquid items at the given tiles as well as the positions and the quantities at each
---position.
---@param tiles Vec2F[]
---@return table<string, {position: Vec2F, quantity: number}[]>
function LiquidGunAltAbility:partitionLiquids(tiles)
  local partition = {}
  for _, tile in ipairs(tiles) do
    -- Lots of checks that result in skipping tiles.

    -- Skip over positions that have tiles over them because liquids that have tiles over them are immortal for some
    -- reason.
    if world.pointCollision(tile) then goto continue1 end

    -- Skip over positions that have tile protection (to prevent infinitely collecting liquids).
    if world.isTileProtected(tile) then goto continue1 end

    local liquidLevel = world.liquidAt(tile)

    if not liquidLevel then goto continue1 end

    -- Get config.
    local liquidConfig = root.liquidConfig(liquidLevel[1])

    -- Skip over liquids that do not have a config or drop an item when collected.
    if not liquidConfig or not liquidConfig.config.itemDrop then goto continue1 end

    local itemName = liquidConfig.config.itemDrop
    -- Add to partition.
    if not partition[itemName] then
      partition[itemName] = {}
    end
    table.insert(partition[itemName], {position = tile, quantity = liquidLevel[2]})

    ::continue1::
  end

  return partition
end

---Attempts to collect as much liquid as possible from the given pool of liquids (without collecting more than one unit
---from each position). Returns the amount collected.
---@param positionsAndQuantities table<string, {position: Vec2F, quantity: number}[]>
---@return integer
function LiquidGunAltAbility:collectLiquidsAtTiles(positionsAndQuantities)

  local liquidsToCollect = {}
  for i = 1, #positionsAndQuantities do
    liquidsToCollect[i] = 0
  end

  local amountCollected = 0
  local remainder = 0  -- Remaining amount that has yet to be collected
  local i = 1
  local j = 1
  local epsilon = 0.05  -- Small number to account for floating-point errors in equality.

  while i <= #positionsAndQuantities do
    local amountToCollect = math.min(1 - remainder, positionsAndQuantities[i].quantity)
    remainder = remainder + amountToCollect

    if 1 - epsilon <= remainder and remainder <= 1 + epsilon then
      -- Collect all liquids between the jth tile and the ith tile
      for k = j, i - 1 do
        local positionAndQuantity = positionsAndQuantities[k]
        liquidsToCollect[k] = liquidsToCollect[k] + positionAndQuantity.quantity
        positionAndQuantity.quantity = positionAndQuantity.quantity - positionAndQuantity.quantity
      end
      local positionAndQuantity = positionsAndQuantities[i]
      liquidsToCollect[i] = liquidsToCollect[i] + amountToCollect
      positionAndQuantity.quantity = positionAndQuantity.quantity - amountToCollect
      remainder = 0

      j = i
      amountCollected = amountCollected + 1
      -- Don't increment i here so we can continue collecting liquid from this spot.
    else
      i = i + 1
    end
  end

  -- Defer actually taking the liquid to here since placing and then destroying a liquid in the same tick tends to cause
  -- some funky stuff to happen.
  for i, quantity in ipairs(liquidsToCollect) do
    local positionAndQuantity = positionsAndQuantities[i]
    self:takeLiquid(positionAndQuantity.position, quantity)
  end

  return amountCollected
end

function LiquidGunAltAbility:takeLiquid(position, amount)
  if amount <= 0 then
    return true
  end

  local liquidLevel = world.destroyLiquid(position)

  if not liquidLevel then
    return false
  end

  if liquidLevel[2] > amount then
    world.spawnLiquid(position, liquidLevel[1], liquidLevel[2] - amount)
  end

  return true
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
  animator.playSound("suckStart")
  animator.playSound("suckLoop", -1)
  activeItem.setScriptedAnimationParameter("shouldEmitSuction", true)
end

function LiquidGunAltAbility:deactivate()
  self.active = false
  animator.stopAllSounds("suckStart")
  animator.stopAllSounds("suckLoop")
  animator.playSound("suckEnd")
  activeItem.setScriptedAnimationParameter("shouldEmitSuction", false)
end

function LiquidGunAltAbility:firePosition()
  return vec2.add(mcontroller.position(), activeItem.handPosition(self.weapon.muzzleOffset))
end

function LiquidGunAltAbility:uninit()
end