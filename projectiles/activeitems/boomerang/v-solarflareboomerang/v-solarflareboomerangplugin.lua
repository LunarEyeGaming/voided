require "/scripts/vec2.lua"
require "/scripts/messageutil.lua"

local pullForce

local collideRadius

local rotationRate

local explosionProjectileType
local explosionProjectileParameters
local explosionDamageFactor

local rotation
local hasCollided
local promises

-- Yes, there is boomerangExtra, but I cannot use it because I need access to self.returning.

local oldInit = init or function() end
local oldUpdate = update or function() end

function init()
  oldInit()

  local pullVerticalDirection = config.getParameter("pullDirection")
  local aimDirection = config.getParameter("baseAimDirection")
  local pullDirection = vec2.rotate(aimDirection, pullVerticalDirection * math.pi / 2)
  pullForce = vec2.mul(pullDirection, config.getParameter("pullForce"))

  collideRadius = config.getParameter("collideRadius")

  rotationRate = config.getParameter("rotationRate")

  explosionProjectileType = config.getParameter("explosionProjectileType")
  explosionProjectileParameters = config.getParameter("explosionProjectileParameters", {})
  explosionDamageFactor = config.getParameter("explosionDamageFactor", 1.0)
  explosionProjectileParameters.power = projectile.power() * explosionDamageFactor
  explosionProjectileParameters.powerMultiplier = projectile.powerMultiplier()

  message.setHandler("v-handleCollision", function(_, _, senderId, ownerId)
    -- If the projectile has not collided yet and the sender has the same source entity as the current projectile...
    if not hasCollided and ownerId == projectile.sourceEntity() then
      world.spawnProjectile(explosionProjectileType, mcontroller.position(), projectile.sourceEntity(), aimDirection,
      false, explosionProjectileParameters)
      mcontroller.setVelocity({0, 0})
      hasCollided = true
    end

    return ownerId == projectile.sourceEntity()
  end)

  rotation = 0
  hasCollided = false
  promises = PromiseKeeper.new()
end

function update(dt)
  oldUpdate(dt)

  rotation = rotation + 2 * math.pi * rotationRate * dt
  mcontroller.setRotation(rotation)

  promises:update()

  -- If the projectile has not collided yet...
  if not hasCollided then
    mcontroller.force(pullForce)

    if self.returning then
      local queriedBoomerangs = world.entityQuery(mcontroller.position(), collideRadius, {callScript = "v_isSolarFlareBoomerang",
      includedTypes = {"projectile"}, order = "nearest", withoutEntityId = entity.id()})
      -- For each boomerang...
      for _, boomerang in ipairs(queriedBoomerangs) do
        -- If the boomerang is close enough...
        if world.magnitude(world.entityPosition(boomerang), mcontroller.position()) < collideRadius then
          -- Collide with it.
          local promise = world.sendEntityMessage(boomerang, "v-handleCollision", entity.id(), projectile.sourceEntity())

          -- Add promise
          promises:add(promise, function(result)
            if not hasCollided and result then
              mcontroller.setVelocity({0, 0})
              hasCollided = true
            end
          end)

          break
        end
      end
    end
  end
end

function v_isSolarFlareBoomerang()
  return true
end