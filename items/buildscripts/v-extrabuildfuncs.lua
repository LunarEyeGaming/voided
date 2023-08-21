--[[
  A script full of extra functions that are commonly used for Voided items, including the application of custom
  rarities.
]]

--[[
  Attempts to apply the given rarity to the config, if it matches any existing rarities. Otherwise, has no effect.
  config: The config table passed in from the build() function
  rarity: A string of any value.
]]
function applyRarity(config, rarity)
  if rarity == "Mythical" then
    config.shortdescription = string.format("^#a600cc;%s^reset;", config.shortdescription)
    if not config.tooltipFields then
      config.tooltipFields = {}
    end
    config.tooltipFields.rarityLabel = "^#a600cc;Mythical"
  end
  
  return config
end

function setVoidedIcon(config)
  if not config.tooltipFields then
    config.tooltipFields = {}
  end
  
  config.tooltipFields.voidedIconImage = "/interface/tooltips/voidedicon.png"
  
  return config
end