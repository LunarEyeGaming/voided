require "/scripts/vec2.lua"

local resetEntity

function init()
  resetPosition = nil

  message.setHandler("v-approachCameraPos", function(_, _, pos)
    approachCameraPos(pos)
  end)
  
  message.setHandler("reset", function(_, _, targetEntity)
    resetEntity = targetEntity
  end)
end

function update()
  if projectile.timeToLive() > 0.5 then
    projectile.setTimeToLive(1.0)
  end
  
  -- If told to reset, then move back to the player and then die once it reaches the player.
  if resetEntity then
    approachCameraPos(world.entityPosition(resetEntity))
    
    if atPos(world.entityPosition(resetEntity)) then
      projectile.die()
    end
  end
end

-- Returns true or false depending on whether or not the camera is at pos.
function approachCameraPos(pos)
  if not atPos(pos) then
    mcontroller.setVelocity(vec2.mul(world.distance(pos, mcontroller.position()), 16))
  else
    mcontroller.setVelocity({0, 0})
  end
end

function atPos(pos)
  -- return vec2.eq(mcontroller.position(), pos)
  return world.magnitude(mcontroller.position(), pos) < 0.1
end