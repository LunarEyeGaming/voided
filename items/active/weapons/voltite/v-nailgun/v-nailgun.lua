require "/scripts/util.lua"
require "/scripts/vec2.lua"
require "/items/active/weapons/weapon.lua"

function init()
  activeItem.setCursor("/cursors/reticle0.cursor")
  animator.setGlobalTag("paletteSwaps", config.getParameter("paletteSwaps", ""))

  self.weapon = Weapon:new()

  self.weapon:addTransformationGroup("weapon", {0,0}, 0)
  self.weapon:addTransformationGroup("muzzle", self.weapon.muzzleOffset, 0)

  local primaryAbility = getPrimaryAbility()
  self.weapon:addAbility(primaryAbility)

  local secondaryAbility = getAltAbility()
  if secondaryAbility then
    self.weapon:addAbility(secondaryAbility)
  end

  self.weapon:init()

  self.weapon.whirMinPitch = config.getParameter("whirMinPitch")
  self.weapon.whirMaxPitch = config.getParameter("whirMaxPitch")
  self.weapon.winddownTime = config.getParameter("winddownTime")

  self.weapon.spinFrameCount = config.getParameter("spinFrameCount")
  self.weapon.startSpinTime = config.getParameter("startSpinTime")
  self.weapon.endSpinTime = config.getParameter("endSpinTime")
  self.weapon.spinTime = self.weapon.startSpinTime
  self.weapon.spinTimer = self.weapon.spinTime
  self.weapon.barrelWinddownTimer = self.weapon.winddownTime
end

function update(dt, fireMode, shiftHeld)
  self.weapon:update(dt, fireMode, shiftHeld)

  if self.weapon.usingBarrelAbility then
    -- If barrel is inactive
    if not self.weapon.activatedBarrel then
      activateBarrel()
    end

    self.weapon.barrelWinddownTimer = self.weapon.winddownTime  -- Reset winddown timer for later use (necessary b/c the barrel can be reactivated even while the weapon is winding down)

    -- Spin barrel
    updateBarrelSpin(dt)
  elseif self.weapon.activatedBarrel then  -- Stopped using barrel ability but the barrel is still active.
    -- Make the barrel slow down
    self.weapon.barrelWinddownTimer = math.max(0, self.weapon.barrelWinddownTimer - dt)

    updateBarrelSpin(dt)

    -- If the barrel has stopped winding down
    if self.weapon.barrelWinddownTimer == 0 then
      deactivateBarrel()
    end
  end
end

-- Starts the barrel animation
function activateBarrel()
  animator.playSound("whir", -1)
  animator.setAnimationState("gun", "fire")

  self.weapon.activatedBarrel = true
end

-- Stops the barrel animation
function deactivateBarrel()
  animator.setAnimationState("gun", "idle")
  animator.stopAllSounds("whir")

  self.weapon.activatedBarrel = false
end

-- Makes the barrel spin.
function updateBarrelSpin(dt)
  -- Update whir pitch and spin rate based on the barrelWinddownTimer
  local progress = self.weapon.barrelWinddownTimer / self.weapon.winddownTime
  self.weapon.spinTime = interp.linear(progress, self.weapon.endSpinTime, self.weapon.startSpinTime)  -- b/c startSpinTime < endSpinTime
  animator.setSoundPitch("whir", interp.linear(progress, self.weapon.whirMinPitch, self.weapon.whirMaxPitch))

  self.weapon.spinTimer = math.max(0, self.weapon.spinTimer - dt)

  -- If spinTimer is zero, reset it
  if self.weapon.spinTimer == 0 then
    self.weapon.spinTimer = self.weapon.spinTime
  end
  self.weapon.spinFrame = math.floor((1 - self.weapon.spinTimer / self.weapon.spinTime) * self.weapon.spinFrameCount) % self.weapon.spinFrameCount
  animator.setGlobalTag("barrelFrame", self.weapon.spinFrame)
end

function uninit()
  self.weapon:uninit()
end
