ModProperty = {}

local cuedRadioMessage = false
local sparkChance = 0.1

function ModProperty.update(position, layer)
  if not cuedRadioMessage then
    world.sendEntityMessage(player.id(), "queueRadioMessage", "v-voltite")
    cuedRadioMessage = true
  end
  
  if math.random() < sparkChance then
    if modLayer == "background" then
      world.spawnProjectile("v-voltitespark2", position)
    else
      world.spawnProjectile("v-voltitespark", position)
    end
  end
end

function ModProperty.destroy(position, layer)
  world.spawnProjectile("v-voltiteexplosion", position, nil, {0, 0}, false, {damageTeam = {type = "environment"}})
end