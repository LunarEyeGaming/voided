--[[
  A script containing some shared code between the centipede segments.
]]

require "/scripts/vec2.lua"
require "/scripts/util.lua"

centipede = {}

---Coroutine. Plays the death animation over time
function centipede.deathAnimation()
  -- PARAMETERS
  local duration = 10
  local shakeOffsetRegion = {-0.5, -0.5, 0.5, 0.5}
  local explosionProjectile = "v-proxyprojectile"
  local explosionProjectileParameters = {
    power = 0,
    actionOnReap = {
      {
        action = "config",
        file = "/projectiles/explosions/v-centipededeathexplosion/v-centipededeathexplosion.config"
      }
    }
  }
  local rumbleRampTime = 8
  local rumbleVolume = 0.4
  local colorSwitchProbability = 0.25  -- Probability of switching color each tick

  local colorIsPhase1 = false
  local timer = 0
  local dt = script.updateDt()

  -- Make invulnerable
  status.addEphemeralEffect("invulnerable", 2 ^ 32)

  -- Begin rumble sound
  animator.playSound("rumble", -1)
  animator.setSoundVolume("rumble", 0)

  util.run(0.1, function() end)  -- Wait for sound volume to update.

  animator.setSoundVolume("rumble", rumbleVolume, rumbleRampTime)

  -- For the duration of the death animation...
  while timer < duration do
    -- Shake
    centipede.shake(shakeOffsetRegion, timer / duration)

    -- Switch color randomly.
    if math.random() <= colorSwitchProbability then
      colorIsPhase1 = not colorIsPhase1
      animator.setGlobalTag("phase", colorIsPhase1 and "1" or "2")
    end

    -- Update timer
    timer = timer + dt

    coroutine.yield()
  end

  -- Spawn explosion
  world.spawnProjectile(explosionProjectile, mcontroller.position(), entity.id(), {1, 0}, false, explosionProjectileParameters)

  centipede.spawnGibs()
end

---Tries to spawn a single ray projectile. Returns the entity ID if successful and `nil` otherwise.
---@return integer?
function centipede.spawnRay()
  local projectileType = "v-centipederay"
  local projectileOffset = {11, 0}

  animator.playSound("ray")

  -- Spawn ray projectile.
  local rayAngle = math.random() * 2 * math.pi
  local rayOffset = vec2.rotate(projectileOffset, rayAngle)
  local rayId = world.spawnProjectile(projectileType, vec2.add(mcontroller.position(), rayOffset),
      entity.id(), vec2.withAngle(rayAngle))

  return rayId
end

---Shakes the current segment for one tick
---@param offsetRegion RectF
---@param progress number
function centipede.shake(offsetRegion, progress)
  animator.resetTransformationGroup("shake")
  animator.translateTransformationGroup("shake", vec2.mul(rect.randomPoint(offsetRegion), progress))
end

---Spawns gibs according to the `deathProjectiles` parameter. `deathProjectiles` is a list of objects each containing
---the following:
---* type: `string` - the type of projectile to spawn
---* direction: `Vec2F` (optional) - the direction of the projectile. Defaults to `{0, 0}`. Adjusts to current rotation
---* offset: `Vec2F` (optional) - the offset from current position to spawn the projectile. Adjusts to current rotation
---* fuzzAngle: `number` (optional) - if defined, rotates direction by a random number from `-fuzzAngle` to `fuzzAngle`
---* parameters: `Json` (optional) - an object containing parameter overrides for the
function centipede.spawnGibs()
  local rotation = mcontroller.rotation()
  local gibs = config.getParameter("deathProjectiles")

  -- For each gib configuration...
  for _, gibConfig in ipairs(gibs) do
    -- Calculate direction
    local direction
    if gibConfig.direction then
      direction = vec2.rotate(gibConfig.direction, rotation)
    else
      direction = {0, 0}
    end

    -- Adjust angle if fuzzAngle is defined.
    if gibConfig.fuzzAngle then
      direction = vec2.rotate(direction, util.toRadians(util.randomInRange({-gibConfig.fuzzAngle, gibConfig.fuzzAngle})))
    end

    local position = mcontroller.position()

    -- If offset is defined, add to spawn position after rotating.
    if gibConfig.offset then
      position = vec2.add(position, vec2.rotate(gibConfig.offset, rotation))
    end

    world.spawnProjectile(gibConfig.type, position, entity.id(), direction, false, gibConfig.parameters)
  end
end