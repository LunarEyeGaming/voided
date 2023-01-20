require "/scripts/vec2.lua"

local smashableRange
local isSmashable

function init()
  smashableRange = config.getParameter("smashableRange")
  smashTreasurePool = config.getParameter("smashTreasurePool")
  
  isSmashable = false

  message.setHandler("v-attract", function(_, _, pos, speed, force)
    attract(pos, speed, force)
    if world.magnitude(pos, mcontroller.position()) < smashableRange then
      isSmashable = true
    end
  end)
end

function attract(pos, speed, force)
  local velocity = vec2.mul(vec2.norm(world.distance(pos, mcontroller.position())), speed)
  mcontroller.approachVelocity(velocity, force)
end

function destroy()
  if isSmashable then
    world.spawnTreasure(mcontroller.position(), smashTreasurePool, world.threatLevel())
  end
end