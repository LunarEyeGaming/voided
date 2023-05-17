require "/scripts/util.lua"
require "/scripts/vec2.lua"

local lightningXPosRange
local lightningYPos
local lightningTimeRange
local projectileType
local projectileParameters

local timer

function init()
  lightningXPosRange = {-50, 50}
  lightningYPos = 30
  existenceThreshold = 50  -- How far from the lightningYPos this object has to be to exist
  lightningTimeRange = {5.0, 30}
  projectileType = "v-lightningbolttelegraph2"
  projectileParameters = {damageTeam = {type = "indiscriminate"}, power = 1000}

  timer = util.randomInRange(lightningTimeRange)
end

function update(dt)
  timer = timer - dt

  if timer < 0 then
    local xPos = util.randomInRange(lightningXPosRange) + stagehand.position()[1]
    local pos = world.lineCollision({xPos, lightningYPos}, vec2.add({xPos, lightningYPos}, {0, 100}))
    
    world.spawnProjectile(projectileType, pos, nil, {0, 1}, false, projectileParameters)
    timer = util.randomInRange(lightningTimeRange)
  end
end