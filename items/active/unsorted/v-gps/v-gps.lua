require "/scripts/vec2.lua"

local isActive
local baseIcon

function init()
  -- Namespacing isActive attribute to avoid conflicts during search by parameter
  isActive = config.getParameter("v-gpsIsActive")
  baseIcon = config.getParameter("baseIcon")
  animator.setAnimationState("gps", isActive and "on" or "off")
end

function update(dt, fireMode)
  if fireMode == "primary" and prevFireMode ~= fireMode then
    toggle()
  end
  prevFireMode = fireMode
end

function toggle()
  -- Do the toggling
  isActive = not isActive

  -- Set "isActive" parameter
  activeItem.setInstanceValue("v-gpsIsActive", isActive)

  -- Update animation.
  animator.setAnimationState("gps", isActive and "on" or "off")
  animator.playSound(isActive and "on" or "off")
  
  -- Update icon.
  activeItem.setInventoryIcon(string.format("%s:%s", baseIcon, isActive and "on" or "off"))
end

function uninit()

end

