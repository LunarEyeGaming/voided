ModProperty = {}

local cuedRadioMessage = false
local sparkChance = 0.1
local radioMessageRange = 25  -- How close the player has to be to trigger the warning message.

function ModProperty.update(position, layer)
  -- If the radio message was not sent and the player is close enough...
  if not cuedRadioMessage and world.magnitude(position, mcontroller.position()) < radioMessageRange then
    -- Make SAIL caution the player about mining this ore.
    world.sendEntityMessage(player.id(), "queueRadioMessage", "v-toxikite")
    cuedRadioMessage = true
  end
  
  -- Emit spark with a probability of sparkChance.
  if math.random() < sparkChance then
    if layer == "background" then
      world.spawnProjectile("v-toxikiteparticlebg", position)
    else
      world.spawnProjectile("v-toxikiteparticlefg", position)
    end
  end
end

function ModProperty.destroy(position, layer)
  world.spawnProjectile("v-toxikiteexplosion", position, nil, {0, 0}, false, {damageTeam = {type = "environment"}, power = 250})
end