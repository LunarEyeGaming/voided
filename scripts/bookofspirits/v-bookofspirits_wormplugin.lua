--[[
  TerraLib's worm primary status script and the way that Book of Spirits listens for damage dealt to monsters do not
  interact well with each other on their own. This script acts to bridge the two by sending a
  `bookOfSpiritsMonsterInteract` message to the source entity every time `takeDamage` is called with a `healthLost`
  amount greater than zero. The script is to be applied to the monster type corresponding to the head of the worm.
]]

-- Comment below is to tell LuaLS to shut up about `takeDamage` not being defined.
---@diagnostic disable-next-line: undefined-global
local oldTakeDamage = takeDamage or function() end

function takeDamage(damageRequest)
  oldTakeDamage(damageRequest)

  -- If more than zero health was lost...
  if damageRequest.damage > 0 then
    -- Send a message to the source entity.
    world.sendEntityMessage(damageRequest.sourceEntityId, "bookOfSpiritsMonsterInteract", entity.id())
  end
end