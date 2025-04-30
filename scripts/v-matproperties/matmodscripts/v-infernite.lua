require "/scripts/vec2.lua"

ModProperty = {}

local cuedRadioMessage = false
local emissionChance = 0.02
local radioMessageRange = 25  -- How close the player has to be to trigger the warning message.

function ModProperty.update(position, layer)
  -- If the radio message was not sent and the player is close enough...
  if not cuedRadioMessage and world.magnitude(position, mcontroller.position()) < radioMessageRange then
    -- Make SAIL caution the player about mining this ore.
    world.sendEntityMessage(player.id(), "queueRadioMessage", "v-infernite")
    cuedRadioMessage = true
  end

  -- Emit particle with a probability of emissionChance.
  if math.random() < emissionChance then
    if layer == "background" then
      world.spawnProjectile("v-inferniteflamebg", position)
    else
      world.spawnProjectile("v-inferniteflamefg", position)
    end
  end
end

function ModProperty.destroy(position, layer)
  world.spawnProjectile("v-inferniteexplosion", position, nil, vec2.withAngle(math.random() * 2 * math.pi), false, {damageTeam = {type = "environment"}})
end