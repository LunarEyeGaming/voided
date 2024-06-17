require "/vehicles/railtram/railtram.lua"

local oldInit = init or function() end
local oldPopVehicle = popVehicle or function() end

local overriddenFields

function init()
  oldInit()

  if not storage.spawnPos then
    storage.spawnPos = mcontroller.position()
  end
  
  overriddenFields = config.getParameter("overriddenFields", jarray())
end

function popVehicle()
  oldPopVehicle()
  
  local overrides = {}
  
  for _, field in ipairs(overriddenFields) do
    overrides[field] = config.getParameter(field)
  end
  
  world.spawnVehicle(config.getParameter("name"), storage.spawnPos, overrides)
end