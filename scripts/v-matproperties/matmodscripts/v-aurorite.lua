ModProperty = {}

local cuedRadioMessage = false
local sparkChance = 0.05
local radioMessageRange = 35  -- How close the player has to be to trigger the warning message.
local chillRange = 20  -- How close the player has to be to become chilled.
local chillWarningChance = 0.05

function ModProperty.update(position, layer, dt)
  -- If the radio message was not sent and the player is close enough...
  if not cuedRadioMessage and world.magnitude(position, mcontroller.position()) < radioMessageRange then
    -- Make SAIL caution the player about mining this ore.
    world.sendEntityMessage(player.id(), "queueRadioMessage", "v-aurorite")
    cuedRadioMessage = true
  end

  if world.magnitude(position, mcontroller.position()) < chillRange then
    status.addEphemeralEffect("v-auroriteeffect")
    world.sendEntityMessage(player.id(), "v-auroriteeffect-freeze", dt)
    if math.random() < chillWarningChance then
      world.spawnProjectile("v-auroritewarning", mcontroller.position(), nil, world.distance(position, mcontroller.position()))
    end
  end

  -- Emit spark with a probability of sparkChance.
  if math.random() < sparkChance then
    if layer == "background" then
      world.spawnProjectile("v-auroriteglowbg", position)
    else
      world.spawnProjectile("v-auroriteglowfg", position)
    end
  end
end

-- function ModProperty.destroy(position, layer)
--   world.spawnProjectile("v-preservedcreature", position, nil, vec2.withAngle(math.random() * 2 * math.pi), false)
-- end