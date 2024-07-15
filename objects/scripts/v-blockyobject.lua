function init()
  local material = config.getParameter("material")
  local spaces = {}
  
  for _, space in ipairs(object.spaces()) do
    table.insert(spaces, {space, material})
  end
  object.setMaterialSpaces(spaces)
end