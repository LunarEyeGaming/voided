function v_scaledPower(power, level)
  if entity.entityType() == "monster" then
    level = level or monster.level()
    power = power * root.evalFunction("monsterLevelPowerMultiplier", level)
  elseif entity.entityType() == "npc" then
    level = level or npc.level()
    power = power * root.evalFunction("npcLevelPowerMultiplierModifier", level)
  else
    error(string.format("Entity type %s is not supported for 'v_scaledPower'", entity.entityType()))
  end
  return power * status.stat("powerMultiplier")
end