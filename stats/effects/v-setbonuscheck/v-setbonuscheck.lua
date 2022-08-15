require "/scripts/voidedutil.lua"

local setBonuses
local chestEffect
local pantsEffect
local setBonusStats
local bonusStatsAdded

function init()
  -- Initialize parameters
  setBonuses = config.getParameter("setBonuses")
  chestEffect = config.getParameter("chestEffect")
  pantsEffect = config.getParameter("pantsEffect")
  setBonusStats = config.getParameter("setBonusStats")
  bonusStatsAdded = false
end

function update(dt)
  chestSlotEquipped = hasStatusEffect(chestEffect)
  pantsSlotEquipped = hasStatusEffect(pantsEffect)
  -- If the chest and pants slots are equipped, then execute the code below
  if chestSlotEquipped and pantsSlotEquipped then
    status.addEphemeralEffects(setBonuses)
    -- When stats are not added yet, if they exist. These are stats, not status effects.
    if setBonusStats and not bonusStatsAdded then
      for _, stat in pairs(setBonusStats) do
        effect.addStatModifierGroup({{stat = stat["stat"], amount = stat["amount"]}})
        bonusStatsAdded = true
      end
    end
  elseif setBonusStats then
    bonusStatsAdded = false
  else
    -- Remove set bonus effects
    for _, bonusEffect in pairs(setBonuses) do
      if type(bonusEffect) == "table" then
        setBonusEffect = bonusEffect["effect"]
      else
        setBonusEffect = bonusEffect
      end
      status.removeEphemeralEffect(setBonusEffect)
    end
  end
  
end
