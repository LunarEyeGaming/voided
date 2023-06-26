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
  
  -- Using config instead of parameters allows tooltipFields to be overridden.
  if not config.tooltipFields then
    config.tooltipFields = {}
  end
  
  if configParameter("customRarity") == "Mythical" then
    config.shortdescription = string.format("^#a600cc;%s^reset;", config.shortdescription)
    config.tooltipFields.rarityLabel = "^#a600cc;Mythical"
  end
  
  -- This way of checking if it's okay to modify the tooltipFields is hacky, but it works. Actually, it may be an
  -- unnecessary special case.
  if configParameter("tooltipKind") == "v-elementalarmor" then
    local statusEffects = configParameter("statusEffects")
    if statusEffects then
      -- Modify tooltipFields to fill in elemental resistances and weaknesses (there's nothing stopping this from
      -- including other stats too)
      for _, stat in ipairs(statusEffects) do
        -- If stat is actually a stat and not a status effect...
        if type(stat) == "table" then
          config.tooltipFields[stat.stat .. "Label"] = getDisplayValue(stat.amount)
        end
      end
    end
  end

  return config, parameters
end

-- Returns a nicely-formatted percent display of the given amount (which is between 0 and 1)
function getDisplayValue(amount)
  -- Convert to a nicely-rounded percentage.
  local percentAmount = math.floor(100 * amount)

  -- Determine sign (add + if positive and nothing otherwise)
  local sign = percentAmount > 0 and "+" or ""

  return string.format("%s%d%%", sign, percentAmount)
end