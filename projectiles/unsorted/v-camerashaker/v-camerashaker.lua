require "/scripts/vec2.lua"
require "/scripts/rect.lua"

local shakeOffsetRegion
local shakeStopTime

local stopTimer

function init()
  shakeOffsetRegion = config.getParameter("shakeOffsetRegion")
  shakeStopTime = config.getParameter("shakeStopTime")

  message.setHandler("v-stopShake", function()
    stopTimer = shakeStopTime
  end)
end

function update(dt)
  local sourceEntity = projectile.sourceEntity()
  if sourceEntity and world.entityExists(sourceEntity) then
    -- Keep alive if the projectile isn't supposed to die yet.
    if projectile.timeToLive() > 0.5 then
      projectile.setTimeToLive(1.0)
    end

    local offsetRegion

    -- If the shaking is stopping...
    if stopTimer then
      stopTimer = stopTimer - dt

      -- If the stop timer has run out...
      if stopTimer <= 0 then
        -- Kill the projectile and abort the call to update on this tick.
        projectile.die()
        return
      end

      -- Lerp shakeOffsetRegion
      offsetRegion = {
        shakeOffsetRegion[1] * stopTimer / shakeStopTime,
        shakeOffsetRegion[2] * stopTimer / shakeStopTime,
        shakeOffsetRegion[3] * stopTimer / shakeStopTime,
        shakeOffsetRegion[4] * stopTimer / shakeStopTime
      }
    else
      offsetRegion = shakeOffsetRegion
    end

    -- Shake!
    mcontroller.setPosition(vec2.add(world.entityPosition(sourceEntity), rect.randomPoint(offsetRegion)))
  end
end