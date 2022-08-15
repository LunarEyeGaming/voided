require "/scripts/util.lua"
require "/scripts/vec2.lua"
require "/scripts/interp.lua"
require "/items/active/weapons/weapon.lua"

local weaponInstance

function init()
  activeItem.setCursor("/cursors/v-beamcannonreticle.cursor")
  animator.setGlobalTag("paletteSwaps", config.getParameter("paletteSwaps", ""))

  weaponInstance = Weapon:new()

  weaponInstance:addTransformationGroup("weapon", {0,0}, 0)
  weaponInstance:addTransformationGroup("muzzle", weaponInstance.muzzleOffset, 0)

  weaponInstance:addAbility(getPrimaryAbility())

  local secondaryAttack = getAltAbility()
  if secondaryAttack then
    weaponInstance:addAbility(secondaryAttack)
  end
  
  weaponInstance:init()
end

function update(dt, fireMode, shiftHeld)
  weaponInstance:update(dt, fireMode, shiftHeld)
end

function uninit()
  weaponInstance:uninit()
end
