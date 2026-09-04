

-- Plugin for handling special stuff.

local oldUpdate = update or function() end
local oldInit = init or function() end

function init()
  oldInit()

  message.setHandler("despawn", despawn)
end

function update(dt)
  local isStunned = status.resourcePositive("stunned")

  if not isStunned then
    oldUpdate(dt)
  elseif capturable then
    capturable.update(dt)
  end
end

function despawn()
  monster.setDropPool(nil)
  monster.setDeathParticleBurst(nil)
  monster.setDeathSound(nil)
  status.addEphemeralEffect("monsterdespawn")
end