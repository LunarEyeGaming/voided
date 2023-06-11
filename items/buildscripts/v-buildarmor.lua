function build(directory, config, parameters, level, seed)
  local configParameter = function(keyName, defaultValue)
    if parameters[keyName] ~= nil then
      return parameters[keyName]
    elseif config[keyName] ~= nil then
      return config[keyName]
    else
      return defaultValue
    end
  end
  
  if configParameter("customRarity") == "Mythical" then
    config.shortdescription = string.format("^#a600cc;%s^reset;", config.shortdescription)
    if not config.tooltipFields then
      config.tooltipFields = {}
    end
    config.tooltipFields.rarityLabel = "^#a600cc;Mythical"
  end

  return config, parameters
end
