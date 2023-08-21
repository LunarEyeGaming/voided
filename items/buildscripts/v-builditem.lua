require "/items/buildscripts/v-extrabuildfuncs.lua"

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
  
  config = applyRarity(config, configParameter("customRarity"))
  config = setVoidedIcon(config)

  return config, parameters
end