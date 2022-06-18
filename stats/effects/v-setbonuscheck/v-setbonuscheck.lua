require "/scripts/voidedutil.lua"

function init()
  -- Initialize parameters
  self.setBonuses = config.getParameter("setBonuses")
  self.chestEffect = config.getParameter("chestEffect")
  self.pantsEffect = config.getParameter("pantsEffect")
  self.setBonusStats = config.getParameter("setBonusStats")
  self.bonusStatsAdded = false
end

function update(dt)
  chestSlotEquipped = hasStatusEffect(self.chestEffect)
  pantsSlotEquipped = hasStatusEffect(self.pantsEffect)
  -- If the chest and pants slots are equipped, then execute the code below
  if chestSlotEquipped and pantsSlotEquipped then
    status.addEphemeralEffects(self.setBonuses)
    -- When stats are not added yet, if they exist. These are stats, not status effects.
    if self.setBonusStats and not self.bonusStatsAdded then
      for _, stat in pairs(self.setBonusStats) do
        effect.addStatModifierGroup({{stat = stat["stat"], amount = stat["amount"]}})
        self.bonusStatsAdded = true
      end
    end
  elseif self.setBonusStats then
    self.bonusStatsAdded = false
  else
    -- Remove set bonus effects
    for _, bonusEffect in pairs(self.setBonuses) do
      if type(bonusEffect) == "table" then
        setBonusEffect = bonusEffect["effect"]
      else
        setBonusEffect = bonusEffect
      end
      status.removeEphemeralEffect(setBonusEffect)
    end
  end
  
end
