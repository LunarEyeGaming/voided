require "/scripts/vec2.lua"

require "/scripts/projectiles/v-mergergeneric.lua"
--[[
  Script for v-inferniteexplosion, which is created as a consequence of mining infernite ore. This script makes the
  projectile merge with others, increasing the ranges and damage of the resulting fire burst. It works by sending
  entity messages to other v-inferniteexplosion projectiles to expire and return their current "potency" (what
  determines the range and damage). It only increases this value if the receivers accept the message. When it receives a
  message, it compares its own ID with the ID of the sender to determine whether to merge (as a means of making sure
  that when two projectiles send merge messages to each other simultaneously, they do not delete each other).
]]

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
  flamePotency = 1  -- Used to scale the flames.
  suppressFlames = false

  vMergeHandler.set("v-inferniteexplosion", true, function()
    return true, flamePotency
  end)

  merger = VMerger:new("v-inferniteexplosion", config.getParameter("mergeRadius"), true, false)
end

function update(dt)
  local results = merger:process()
  for _, result in ipairs(results) do
    flamePotency = flamePotency + result
  end
end

function destroy()
  -- If the projectile has not received a request to merge...
  if not vMergeHandler.isMerged then
    -- Load parameters
    local offset = config.getParameter("spawnOffset", {0, 0})
    local projectileType = config.getParameter("projectileType")
    local projectileCount = config.getParameter("projectileCount")
    local baseSpeed = config.getParameter("baseProjectileSpeed")
    local maxSpeed = config.getParameter("maxProjectileSpeed")
    local baseDamage = config.getParameter("baseProjectileDamage")
    local maxDamage = config.getParameter("maxProjectileDamage")
    local explosionActions = config.getParameter("explosionActions")

    local params = {
      speed = maxSpeed and math.min(maxSpeed, baseSpeed * flamePotency) or baseSpeed * flamePotency,
      power = maxDamage and math.min(maxDamage, baseDamage * flamePotency) or baseDamage * flamePotency,
      damageTeam = entity.damageTeam(),
      damageRepeatGroup = "v-inferniteexplosion"
    }

    local ownPos = mcontroller.position()

    spawnProjectileRing(projectileType, vec2.add(ownPos, offset), projectileCount, params)

    if explosionActions then
      -- Sort explosion actions by potency threshold in descending order.
      table.sort(explosionActions, function(action1, action2)
        return action1.potencyThreshold > action2.potencyThreshold
      end)
      -- Process the first action with a threshold that is less than or equal to flamePotency.
      for _, action in ipairs(explosionActions) do
        if flamePotency >= action.potencyThreshold then
          projectile.processAction(action)
        end
      end
    end
  end
end

function spawnProjectileRing(type_, pos, count, params)
  -- Spawn projectiles in a 360-degree spread.
  for i = 1, count do
    local angle = 2 * math.pi * i / count

    world.spawnProjectile(type_, pos, projectile.sourceEntity(), vec2.withAngle(angle), false, params)
  end
end