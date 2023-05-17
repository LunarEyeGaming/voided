-- require "/scripts/projectiles/v-shockwavespawner.lua"

local mergeRadius

local mergePromises
local boltPotency
local hasMerged
local awaitingMerge
local isAbsorber

function init()
  message.setHandler("v-voltiteMerge", function()
    -- If it has not already merged and it is not waiting for any merge requests...
    if not hasMerged and not awaitingMerge and not isAbsorber then
      -- sb.logInfo("%s received message", entity.id())
      projectile.die()
      hasMerged = true

      return boltPotency
    end
  end)
  
  mergeRadius = 3

  mergePromises = {}
  boltPotency = 1
  hasMerged = false
  -- Using #mergePromises == 0 as a test for awaiting a merge does not work because a message may be handled before
  -- world.sendEntityMessage() returns.
  awaitingMerge = false
  isAbsorber = false
end

function update(dt)
  if math.random(1, 2) == 1 then
    broadcastMergeRequests()
  end
  
  processPromises()
  
  -- If no more promises are present, set awaitingMerge to false
  if #mergePromises == 0 then
    awaitingMerge = false
  end
end

function destroy()
  -- sb.logInfo("potency: %s, hasMerged: %s", boltPotency, hasMerged)
  if not hasMerged or isAbsorber then
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

    local ownPos = mcontroller.position()
    world.spawnMonster(monsterType, {ownPos[1] + offset[1], ownPos[2] + offset[2]}, monsterParameters)
  end
end

function processPromises()
  local i = 1
  while i <= #mergePromises do
    local promise = mergePromises[i]
    
    -- If a promise finished, handle its result and remove it.
    if promise:finished() then
      if promise:succeeded() then
        local result = promise:result()

        -- If the projectile accepted the message, combine boltPotency values and turn it into an absorber (which no
        -- longer accepts merge requests).
        if result then
          boltPotency = boltPotency + promise:result()
          isAbsorber = true
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
  local queried = world.entityQuery(mcontroller.position(), mergeRadius, {includedTypes = {"projectile"}, withoutEntityId = entity.id()})
  
  for _, id in ipairs(queried) do
    awaitingMerge = true
    -- sb.logInfo("Before message %s", entity.id())
    table.insert(mergePromises, world.sendEntityMessage(id, "v-voltiteMerge"))
    -- sb.logInfo("After message %s", entity.id())
  end
end