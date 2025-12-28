require "/scripts/vec2.lua"

function init()
  local pos = vec2.add(object.position(), {2, 4})
  world.spawnMonster("v-anemone", pos, {level = object.level()})
end