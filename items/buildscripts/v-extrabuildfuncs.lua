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

--[[
  Modifies the item to use the Voided icon.
  config: The config table passed in from the build() function
]]
function setVoidedIcon(config)
  if not config.tooltipFields then
    config.tooltipFields = {}
  end

  config.tooltipFields.voidedIconImage = "/interface/tooltips/voidedicon.png"

  return config
end

--[[
  Adds a hidden prefix to the short description of an item.
  config: The config table passed in from the build() function
  prefix: The prefix to add
]]
function addExtraInfo(config, info)
  if info then
    if not config.tooltipFields then
      config.tooltipFields = {}
    end
    config.tooltipFields.extraInfoLabel = info
  end

  return config
end

--[[
  Applies all extra build functions, including applyRarity, setVoidedIcon, and addPrefix. All arguments are to be passed
  in from a build() function.
]]
function applyExtraBuildFuncs(directory, config, parameters, level, seed)
  local configParameter = function(keyName, defaultValue)
    if parameters[keyName] ~= nil then
      return parameters[keyName]
    elseif config[keyName] ~= nil then
      return config[keyName]
    else
      return defaultValue
    end
  end

  config = applyRarity(config, configParameter("customRarity"))
  config = setVoidedIcon(config)
  config = addExtraInfo(config, configParameter("extraInfo"))

  return config, parameters
end