require "/scripts/vec2.lua"
--[[
  Script for v-inferniteexplosion, which is created as a consequence of mining infernite ore. This script makes the
  projectile merge with others, increasing the ranges and damage of the resulting fire burst. It works by sending
  entity messages to other v-inferniteexplosion projectiles to expire and return their current "potency" (what
  determines the range and damage). It only increases this value if the receivers accept the message. When it receives a
  message, it compares its own ID with the ID of the sender to determine whether to merge (as a means of making sure
  that when two projectiles send merge messages to each other simultaneously, they do not delete each other).
]]

local mergeRadius

local mergePromises
local flamePotency
local suppressFlames
-- local awaitingMerge
-- local isAbsorber

function init()
  message.setHandler("v-inferniteMerge", function(_, _, sourceId)
    -- This comparison is arbitrary and is made to prevent both bolts from disappearing.
    if not suppressFlames and entity.id() < sourceId then
      -- sb.logInfo("%s received message", entity.id())
      projectile.die()
      suppressFlames = true  -- Suppress shockwave

      return flamePotency
    end
  end)

  mergeRadius = config.getParameter("mergeRadius")

  mergePromises = {}
  flamePotency = 1  -- Used to scale the flames.
  suppressFlames = false
end

function update(dt)
  broadcastMergeRequests()

  processPromises()
end

function destroy()
  -- If the projectile has not merged...
  if not suppressFlames then
    -- Load parameters
    local offset = config.getParameter("spawnOffset", {0, 0})
    local projectileType = config.getParameter("projectileType")
    local projectileCount = config.getParameter("projectileCount")
    local baseSpeed = config.getParameter("baseProjectileSpeed")
    local maxSpeed = config.getParameter("maxProjectileSpeed")
    local baseDamage = config.getParameter("baseProjectileDamage")
    local maxDamage = config.getParameter("maxProjectileDamage")
    local explosionAction = config.getParameter("explosionAction")

    local params = {
      speed = maxSpeed and math.min(maxSpeed, baseSpeed * flamePotency) or baseSpeed * flamePotency,
      power = maxDamage and math.min(maxDamage, baseDamage * flamePotency) or baseDamage * flamePotency,
      damageTeam = entity.damageTeam(),
      damageRepeatGroup = "v-inferniteexplosion"
    }

    local ownPos = mcontroller.position()

    -- Spawn projectiles in a 360-degree spread.
    for i = 1, projectileCount do
      local angle = 2 * math.pi * i / projectileCount

      world.spawnProjectile(projectileType, vec2.add(ownPos, offset), projectile.sourceEntity(), vec2.withAngle(angle),
      false, params)
    end

    if explosionAction then
      projectile.processAction(explosionAction)
    end
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

        -- If the projectile accepted the message, combine flamePotency values
        if result then
          flamePotency = flamePotency + promise:result()
        end
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
    table.insert(mergePromises, world.sendEntityMessage(id, "v-inferniteMerge", entity.id()))
    -- sb.logInfo("After message %s", entity.id())
  end
end