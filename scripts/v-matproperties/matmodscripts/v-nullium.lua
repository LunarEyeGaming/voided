require "/scripts/rect.lua"

require "/scripts/v-world.lua"

ModProperty = {}

local cuedRadioMessage = false
local sparkChance = 0.1
local radioMessageRange = 25  -- How close the player has to be to trigger the warning message.

function ModProperty.update(position, layer)
  -- If the radio message was not sent and the player is close enough...
  if not cuedRadioMessage and world.magnitude(position, mcontroller.position()) < radioMessageRange then
    -- Make SAIL caution the player about mining this ore.
    world.sendEntityMessage(player.id(), "queueRadioMessage", "v-nullium")
    cuedRadioMessage = true
  end

  -- Emit spark with a probability of sparkChance.
  if math.random() < sparkChance then
    if layer == "background" then
      world.spawnProjectile("v-nulliumparticlebg", position)
    else
      world.spawnProjectile("v-nulliumparticlefg", position)
    end
  end
end

function ModProperty.destroy(position, layer)
  world.spawnProjectile("v-voidbubble", position, nil, {0, 0}, false, {damageTeam = {type = "indiscriminate"}})
end