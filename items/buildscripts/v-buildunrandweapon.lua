require "/scripts/util.lua"
require "/scripts/vec2.lua"
require "/scripts/versioningutils.lua"
require "/items/buildscripts/abilities.lua"
require "/items/buildscripts/buildunrandweapon.lua"

local oldBuild = build

function build(directory, config, parameters, level, seed)
  config, parameters = oldBuild(directory, config, parameters, level, seed)

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
    config.tooltipFields.rarityLabel = "^#a600cc;Mythical"
  end

  return config, parameters
end
