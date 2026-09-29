local strongEnoughEquipmentLevels

function init()
  strongEnoughEquipmentLevels = {9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20}

  message.setHandler("v-equipmentstrengthprovider-check", hasStrongEnoughEquipment)
end

---Returns whether or not the player has at least one item with a `level` value that is inside `strongEnoughEquipmentLevels`.
---@return boolean
function hasStrongEnoughEquipment()
  for _, level in ipairs(strongEnoughEquipmentLevels) do
    if player.hasItemWithParameter("level", level) then
      return true
    end
  end

  return false
end
