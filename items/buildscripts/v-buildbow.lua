-- require "/scripts/util.lua"
-- require "/scripts/vec2.lua"
-- require "/scripts/versioningutils.lua"
-- require "/items/buildscripts/abilities.lua"
require "/items/buildscripts/v-extrabuildfuncs.lua"
require "/items/buildscripts/buildbow.lua"

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

  config = applyRarity(config, configParameter("customRarity"))
  config = setVoidedIcon(config)

  return config, parameters
end
