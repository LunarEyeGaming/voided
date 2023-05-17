require "/scripts/util.lua"
require "/scripts/vec2.lua"

local lightningXPosRange
local lightningYPos
local lightningTimeRange

local timer

function init()
  lightningXPosRange = {-50, 50}
  lightningYPos = 30
  lightningTimeRange = {0.5, 5}

  timer = util.randomInRange(lightningTimeRange)
end

function update(dt)
  timer = timer - dt

  if timer < 0 then
    local xPos = util.randomInRange(lightningXPosRange) + mcontroller.xPosition()
    local pos = world.lineCollision({xPos, lightningYPos}, vec2.add({xPos, lightningYPos}, {0, 100}))
    
    world.spawnProjectile("v-lightningbolttelegraph2", pos, nil, {0, 1}, false, {damageTeam = {type = "indiscriminate"}, power = 1000})
    timer = util.randomInRange(lightningTimeRange)
  end
end