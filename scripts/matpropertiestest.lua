ModProperty = {}

ModProperty.name = "v-voltite"

local testVar1

function ModProperty.init()
  testVar1 = 0
end

function ModProperty.update(position, layer)
  
  world.debugText("Test", position, "green")
end