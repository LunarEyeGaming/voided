require "/items/active/weapons/other/adaptablecrossbow/adaptableammo.lua"
require "/scripts/util.lua"

AncientRifleModes = AdaptableAmmo:new()

function AncientRifleModes:adaptAbility()
  local ability = self.weapon.abilities[self.adaptedAbilityIndex]
  util.mergeTable(ability, copy(self.ammoTypes[self.ammoIndex]))  -- use copy to protect ammoTypes from mutations
  animator.setAnimationState("ammoType", tostring(self.ammoIndex))

  activeItem.setInventoryIcon(string.format("%s:%d", self.baseIcon, self.ammoIndex))

  if item.tooltipKind() ~= "base" then
    self:updateTooltip()
  end
end

function AncientRifleModes:updateTooltip()
  local tooltipFields = config.getParameter("tooltipFields")
  local ammoType = self.ammoTypes[self.ammoIndex]
  local damageLevelMultiplier = root.evalFunction("weaponDamageLevelMultiplier", config.getParameter("level", 1))
  tooltipFields.speedLabel = util.round(1 / (ammoType.fireTime or 1.0), 1)
  tooltipFields.damagePerShotLabel = util.round((ammoType.baseDps or 0) * (ammoType.fireTime or 1.0) * damageLevelMultiplier, 1)
  tooltipFields.energyPerShotLabel = util.round((ammoType.energyUsage or 0) * (ammoType.fireTime or 1.0), 1)
  activeItem.setInstanceValue("tooltipFields", tooltipFields)
end