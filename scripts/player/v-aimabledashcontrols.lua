require "/scripts/util.lua"

local aimableDashTechs
local aimableDashSpecial2Techs

function init()
  aimableDashTechs = {
    "v-aimabledash",
    "v-aimableblink",
    "v-aimablemultidash"
  }
  aimableDashSpecial2Techs = {}
  for _, techName in ipairs(aimableDashTechs) do
    table.insert(aimableDashSpecial2Techs, techName .. "-special2")
  end
  message.setHandler("v-aimabledashcontrols-setUseSpecial2", function(_, _, useSpecial2)
    local fromTable, toTable
    -- Swap with special 2 variant.
    if useSpecial2 then
      fromTable = aimableDashTechs
      toTable = aimableDashSpecial2Techs
    else
      fromTable = aimableDashSpecial2Techs
      toTable = aimableDashTechs
    end

    -- Store lists to insulate these values from side effects
    local available = player.availableTechs()
    local enabled = player.enabledTechs()
    local equippedTech = player.equippedTech("body")

    -- Reveal all tech variants in toTable that are revealed in fromTable
    for _, techName in ipairs(available) do
      local idx = indexOf(fromTable, techName)
      if idx then
        player.makeTechAvailable(toTable[idx])
        player.makeTechUnavailable(techName)
      end
    end

    -- Enable all tech variants in toTable that are revealed in fromTable
    for _, techName in ipairs(enabled) do
      local idx = indexOf(fromTable, techName)
      if idx then
        player.enableTech(toTable[idx])
      end
    end

    -- Swap out equipped tech
    local idx = indexOf(fromTable, equippedTech)
    if idx then
      player.equipTech(toTable[idx])
    end
  end)
end

function indexOf(t, v)
  for i, v2 in ipairs(t) do
    if v2 == v then
      return i
    end
  end
end