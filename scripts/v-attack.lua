---Set of utility functions relating to attacks.
---@class vAttack
vAttack = {}

---Returns the power scaled to the provided level (or the entity's level by default).
---@param power number
---@param level? number
---@return number
function vAttack.scaledPower(power, level)
  if entity.entityType() == "monster" then
    level = level or monster.level()
    power = power * root.evalFunction("monsterLevelPowerMultiplier", level)
  elseif entity.entityType() == "npc" then
    level = level or npc.level()
    power = power * root.evalFunction("npcLevelPowerMultiplierModifier", level)
  else
    error(string.format("Entity type %s is not supported for 'vAttack.scaledPower'", entity.entityType()))
  end
  return power * status.stat("powerMultiplier")
end