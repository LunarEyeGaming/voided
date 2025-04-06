vConfig = {}

---Imports the given parameters into the current environment. A pair of values as an argument
---signifies a parameter with a default.
---
---As this modifies the contents of `_ENV`, using this function without care can produce unpredictable results.
---@param ... string | [string, any]
function vConfig.bindParameters(...)
  for _, param in ipairs(...) do
    if type(param) == "string" then
      _ENV[param] = config.getParameter(param)
    else
      _ENV[param[1]] = config.getParameter(param[1], param[2])
    end
  end
end