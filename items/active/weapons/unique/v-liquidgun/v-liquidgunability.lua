require "/items/active/weapons/ranged/gunfire.lua"

require "/scripts/v-animator.lua"

LiquidGunAbility = GunFire:new()

function LiquidGunAbility:init()
  GunFire.init(self)

  self.currentLiquid = self:getLiquid()
  self.active = false
end

function LiquidGunAbility:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)

  self.inProtectedArea = world.isTileProtected(mcontroller.position())
  self.currentLiquid = self:getLiquid()
  activeItem.setScriptedAnimationParameter("currentLiquid", self.currentLiquid)

  if self.currentLiquid then
    if not self.prevLiquid or self.currentLiquid.name ~= self.prevLiquid.name then
      local liquidName = self:getLiquidName(self.currentLiquid)
      local liquidAttributes = self:getLiquidAttributes(liquidName)

      animator.setGlobalTag("liquidColor", vAnimator.colorToString(liquidAttributes.color))
      animator.setLightColor("glow", liquidAttributes.glowColor or {0, 0, 0})
    end
  else
    animator.setGlobalTag("liquidColor", "00000000")
    animator.setLightColor("glow", {0, 0, 0})
  end

  self.cooldownTimer = math.max(0, self.cooldownTimer - self.dt)

  if animator.animationState("firing") ~= "fire" then
    animator.setLightActive("muzzleFlash", false)
  end

  if self.fireMode == (self.activatingFireMode or self.abilitySlot)
    and not self.weapon.currentAbility
    and self.cooldownTimer == 0
    and not world.lineTileCollision(mcontroller.position(), self:firePosition()) then

    if self.fireType == "auto" and self:consumeLiquid() then
      self:setState(self.auto)
    elseif self.fireType == "burst" then
      self:setState(self.burst)
    end
  end

  if self.weapon.currentAbility == self then
    if not self.active then self:activate() end
  elseif self.active then
    self:deactivate()
  end

  self.prevLiquid = self.currentLiquid
end

function LiquidGunAbility:fireProjectile(projectileType, projectileParams, inaccuracy, firePosition, projectileCount)
  local params = sb.jsonMerge(self.projectileParameters, projectileParams or {})
  params.power = self:damagePerShot()
  params.powerMultiplier = activeItem.ownerPowerMultiplier()
  params.speed = util.randomInRange(params.speed)

  -- Create undefined parameters
  -- if not params.actionOnReap then
  --   params.actionOnReap = {}
  -- end
  if not params.periodicActions then
    params.periodicActions = {}
  end

  local liquidName = self:getLiquidName(self.currentLiquid)
  -- table.insert(params.actionOnReap, {
  --   action = "liquid",
  --   quantity = self.projectileLiquidQuantity,
  --   liquid = liquidName
  -- })
  params.liquidPlacer = {
    name = liquidName,
    placeOnDestroy = true
  }


  local liquidAttributes = self:getLiquidAttributes(liquidName)

  if type(self.projectileParticle) ~= "table" then
    error("projectileParticle is not an object (must define the particle in the activeitem file directly)")
  end

  local particle = sb.jsonMerge(self.projectileParticle, {
    color = liquidAttributes.color,
    light = liquidAttributes.glowColor
  })
  params.processing = "?multiply=" .. vAnimator.colorToString(liquidAttributes.color)
  -- params.statusEffects = liquidAttributes.statusEffects

  table.insert(params.periodicActions, {
    time = self.projectileParticleInterval,
    action = "particle",
    rotate = true,
    specification = particle
  })

  if not projectileType then
    projectileType = self.projectileType
  end
  if type(projectileType) == "table" then
    projectileType = projectileType[math.random(#projectileType)]
  end

  local projectileId = 0
  for i = 1, (projectileCount or self.projectileCount) do
    if params.timeToLive then
      params.timeToLive = util.randomInRange(params.timeToLive)
    end

    projectileId = world.spawnProjectile(
        projectileType,
        firePosition or self:firePosition(),
        activeItem.ownerEntityId(),
        self:aimVector(inaccuracy or self.inaccuracy),
        false,
        params
      )
  end
  return projectileId
end

function LiquidGunAbility:activate()
  self.active = true
  animator.playSound("fireStart")
  animator.playSound("fireLoop", -1)
end

function LiquidGunAbility:deactivate()
  self.active = false
  animator.stopAllSounds("fireStart")
  animator.stopAllSounds("fireLoop")
  animator.playSound("fireEnd")
end

---Attempts to consume a liquid from the player's inventory. Returns the liquid consumed, or `nil` if none was consumed.
---If in a protected area, consumes energy instead.
function LiquidGunAbility:consumeLiquid()
  if self.inProtectedArea then
    return (self.energyUsage <= 0 or not status.resourceLocked("energy"))
    and status.overConsumeResource("energy", self:energyPerShot())
  end

  local liquid = self:getLiquid()

  if liquid then
    liquid.count = 1  -- Ask to consume one unit of liquid.
    player.consumeItem(liquid)
  end

  return liquid
end

function LiquidGunAbility:getLiquidName(descriptor)
  local itemConfig = root.itemConfig(descriptor)
  if not itemConfig.config.liquid then
    error("Item config for " .. descriptor .. " does not contain 'liquid'")
  end

  return itemConfig.config.liquid
end

---Returns a liquid from the player's inventory.
function LiquidGunAbility:getLiquid()
  return player.getItemWithParameter("category", "liquid")
end

function LiquidGunAbility:getLiquidAttributes(liquid)
  local liquidConfig = root.liquidConfig(liquid)

  if not liquidConfig then
    error("Invalid liquid: " .. liquid)
  end

  return {
    color = liquidConfig.config.color,
    glowColor = liquidConfig.config.radiantLight,
    statusEffects = liquidConfig.config.statusEffects
  }
end