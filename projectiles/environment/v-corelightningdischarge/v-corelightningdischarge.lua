require "/scripts/util.lua"
require "/scripts/vec2.lua"

local fuzzAngle
local numSplits
local splitCount

local shouldSplit

function init()
  fuzzAngle = util.toRadians(25)
  numSplits = config.getParameter("numSplits")
  splitCount = 2
  
  shouldSplit = true
end

function update(dt)
  if world.isTileProtected(mcontroller.position()) then
    shouldSplit = false
    projectile.die()
  end
end

function destroy()
  if numSplits > 0 and shouldSplit then
    local aimVector = mcontroller.velocity()
    
    for i = 1, splitCount do
      world.spawnProjectile(
        config.getParameter("projectileName"), 
        mcontroller.position(),
        projectile.sourceEntity(),
        vec2.rotate(aimVector, util.randomInRange({-fuzzAngle, fuzzAngle})),
        false,
        {power = projectile.power(), powerMultiplier = projectile.powerMultiplier(), numSplits = numSplits - 1, damageTeam = entity.damageTeam()}
      )
    end
  end
end