-- require "/scripts/projectiles/v-shockwavespawner.lua"
--[[
  Script for v-voltiteexplosionbolt, which is created as a consequence of mining voltite ore. This script makes the
  bolt merge with others, increasing the size and damage of the resulting electric shock. It works by sending entity
  messages to other bolts to expire and return their current "potency" (what determines the size and damage). It only
  increases this value if the receivers accept the message. When it receives a message, it compares its own ID with the 
  ID of the sender to determine whether to merge (as a means of making sure that when two bolts send merge messages to
  each other simultaneously, they do not delete each other).
]]

local mergeRadius

local mergePromises
local boltPotency
local suppressShockwave
-- local awaitingMerge
-- local isAbsorber

function init()
  message.setHandler("v-voltiteMerge", function(_, _, sourceId)
    -- This comparison is arbitrary and is made to prevent both bolts from disappearing.
    if not suppressShockwave and entity.id() < sourceId then
      -- sb.logInfo("%s received message", entity.id())
      projectile.die()
      suppressShockwave = true  -- Suppress shockwave

      return boltPotency
    end
  end)
  
  mergeRadius = config.getParameter("mergeRadius")

  mergePromises = {}
  boltPotency = 1  -- Used to scale the shockwave.
  suppressShockwave = false
  -- Using #mergePromises == 0 as a test for awaiting a merge does not work because a message may be handled before
  -- world.sendEntityMessage() returns.
  -- awaitingMerge = false
  -- isAbsorber = false
end

function update(dt)
  broadcastMergeRequests()
  
  processPromises()
  
  -- -- If no more promises are present, set awaitingMerge to false
  -- if #mergePromises == 0 then
    -- awaitingMerge = false
  -- end
end

function destroy()
  -- sb.logInfo("potency: %s, suppressShockwave: %s, id: %s", boltPotency, suppressShockwave, entity.id())
  
  -- If the projectile has not merged...
  if not suppressShockwave then
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
    --world.spawnProjectile("invisibleprojectile", mcontroller.position(), projectile.sourceEntity(), {0, 0}, false, {bounces = -1})
  end
end

-- Process promises for entity messages
function processPromises()
  local i = 1
  while i <= #mergePromises do
    local promise = mergePromises[i]
    
    -- If a promise finished, handle its result and remove it.
    if promise:finished() then
      if promise:succeeded() then
        local result = promise:result()

        -- If the projectile accepted the message, combine boltPotency values
        if result then
          boltPotency = boltPotency + promise:result()
          -- isAbsorber = true
        end
      -- else
        -- sb.logError("Promise failed: %s", promise:error())
      end

      table.remove(mergePromises, i)
    else
      i = i + 1
    end
  end
end

function broadcastMergeRequests()
  local queried = world.entityQuery(mcontroller.position(), mergeRadius, {includedTypes = {"projectile"}, 
      withoutEntityId = entity.id()})
  
  -- Merge with other bolts
  for _, id in ipairs(queried) do
    -- awaitingMerge = true
    -- sb.logInfo("Before message %s", entity.id())
    table.insert(mergePromises, world.sendEntityMessage(id, "v-voltiteMerge", entity.id()))
    -- sb.logInfo("After message %s", entity.id())
  end
end