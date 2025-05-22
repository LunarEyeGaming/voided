require "/scripts/projectiles/v-mergergeneric.lua"
--[[
  Script for v-voltiteexplosionbolt, which is created as a consequence of mining voltite ore. This script makes the
  bolt merge with others, increasing the size and damage of the resulting electric shock. It works by sending entity
  messages to other bolts to expire and return their current "potency" (what determines the size and damage). It only
  increases this value if the receivers accept the message. When it receives a message, it compares its own ID with the
  ID of the sender to determine whether to merge (as a means of making sure that when two bolts send merge messages to
  each other simultaneously, they do not delete each other).
]]

local boltPotency

local merger

function init()
  boltPotency = 1  -- Used to scale the shockwave.

  vMergeHandler.set("v-voltiteexplosionbolt", true, function()
    return true, boltPotency
  end)

  merger = VMerger:new("v-voltiteexplosionbolt", config.getParameter("mergeRadius"), true, false)
end

function update(dt)
  local results = merger:process()
  for _, result in ipairs(results) do
    boltPotency = boltPotency + result
  end
end

function destroy()
  -- If the projectile has not received a request to merge...
  if not vMergeHandler.isMerged then
    -- Load parameters
    local offset = config.getParameter("spawnOffset", {0, 0})
    local damageFactor = config.getParameter("shockwaveDamageFactor", 1.0)
    local monsterType = config.getParameter("monsterType")
    local maxAreaMultiplier = config.getParameter("maxAreaMultiplier")
    local monsterParameters = config.getParameter("monsterParameters", {})
    local baseDamage = (monsterParameters.damage or (projectile.power() * damageFactor)) * projectile.powerMultiplier()
    local maxDamage = config.getParameter("maxDamage") * projectile.powerMultiplier()
    monsterParameters.damage = math.min(baseDamage * boltPotency, maxDamage)

    -- Use the damage team specified if available. Otherwise, inherit the current entity's damage team.
    monsterParameters.damageTeamType = monsterParameters.damageTeamType or entity.damageTeam().type
    monsterParameters.damageTeam = monsterParameters.damageTeam or entity.damageTeam().team

    -- Calculate size of shockwave.
    monsterParameters.maxArea = maxAreaMultiplier * boltPotency

    -- Create shockwave
    local ownPos = mcontroller.position()
    world.spawnMonster(monsterType, {ownPos[1] + offset[1], ownPos[2] + offset[2]}, monsterParameters)
  end
end