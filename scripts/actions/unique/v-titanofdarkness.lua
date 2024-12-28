require "/scripts/util.lua"
require "/scripts/vec2.lua"
require "/scripts/v-attack.lua"
require "/scripts/actions/flying.lua"
require "/scripts/v-world.lua"

-- param target
-- param windupTime
-- param attackTime
function v_titanLaserRotation(args, board)
  local rq = vBehavior.requireArgsGen("v_titanLaserRotation", args)

  if not rq{"target", "windupTime", "attackTime"} then return false end

  local targetPos = world.entityPosition(args.target)  -- Get target position
  -- Get eye centers
  local leftEyeCenter = animator.partPoint("body", "leftEyeCenter")
  local rightEyeCenter = animator.partPoint("body", "rightEyeCenter")
  -- Calculate starting eye angles
  local leftEyeStartAngle = vec2.angle(world.distance(targetPos, vec2.add(leftEyeCenter, mcontroller.position())))
  local rightEyeStartAngle = vec2.angle(world.distance(targetPos, vec2.add(rightEyeCenter, mcontroller.position())))

  -- Show telegraph
  animator.setAnimationState("lasers", "windup")

  animator.resetTransformationGroup("leftbeam")
  animator.resetTransformationGroup("rightbeam")
  animator.rotateTransformationGroup("leftbeam", leftEyeStartAngle, leftEyeCenter)
  animator.rotateTransformationGroup("rightbeam", rightEyeStartAngle, rightEyeCenter)

  util.run(args.windupTime, function() end)

  -- Get new angles to determine the direction of the lasers.
  targetPos = world.entityPosition(args.target)
  local leftEyeTestAngle = vec2.angle(world.distance(targetPos, vec2.add(leftEyeCenter, mcontroller.position())))
  local rightEyeTestAngle = vec2.angle(world.distance(targetPos, vec2.add(rightEyeCenter, mcontroller.position())))

  -- Determine direction.
  local direction = util.toDirection(util.angleDiff(leftEyeStartAngle, leftEyeTestAngle) + util.angleDiff(rightEyeStartAngle, rightEyeTestAngle))
  -- Calculate ending eye angles
  local leftEyeEndAngle = leftEyeStartAngle + 2 * math.pi * direction
  local rightEyeEndAngle = rightEyeStartAngle + 2 * math.pi * direction

  animator.setAnimationState("lasers", "fire")

  local timer = 0

  -- Make lasers do one full revolution.
  util.run(args.attackTime, function(dt)
    local leftEyeAngle = util.lerp(timer / args.attackTime, leftEyeStartAngle, leftEyeEndAngle)
    local rightEyeAngle = util.lerp(timer / args.attackTime, rightEyeStartAngle, rightEyeEndAngle)

    -- Rotate lasers
    animator.resetTransformationGroup("leftbeam")
    animator.resetTransformationGroup("rightbeam")
    animator.rotateTransformationGroup("leftbeam", leftEyeAngle, leftEyeCenter)
    animator.rotateTransformationGroup("rightbeam", rightEyeAngle, rightEyeCenter)

    timer = timer + dt
  end)

  animator.setAnimationState("lasers", "fireEnd")

  return true
end

-- param target
-- param requiredSafeArea
-- param spawnRegion
-- param projectileType
-- param projectileParameters
-- param teleportDelay
-- param postTeleportTime
-- param repeats - Number of times to repeat the attack
function v_titanExplosionAttack(args, board)
  local rq = vBehavior.requireArgsGen("v_titanExplosionAttack", args)

  if not rq{"target", "requiredSafeArea", "spawnRegion", "projectileType", "teleportDelay", "postTeleportTime",
  "repeats"} then
    return false
  end

  local spawnRegion = rect.translate(args.spawnRegion, mcontroller.position())
  local projectileParameters = copy(args.projectileParameters or {})
  projectileParameters.power = vAttack.scaledPower(projectileParameters.power or 10)

  for i = 1, args.repeats do
    -- Choose a spawn position that guarantees an area free of collisions
    local spawnPos
    repeat
      spawnPos = rect.randomPoint(spawnRegion)
    until not world.rectCollision(rect.translate(args.requiredSafeArea, spawnPos))

    world.spawnProjectile(args.projectileType, spawnPos, entity.id(), {0, 0}, false, {power = vAttack.scaledPower(10)})

    util.run(args.teleportDelay, function() end)

    world.sendEntityMessage(args.target, "v-teleport", spawnPos)

    util.run(args.postTeleportTime, function() end)
  end

  return true
end

-- param projectileCount
-- param projectileType
-- param projectileParameters
-- param flickDelay
-- param flickInterval
-- param flickCount
-- param target
function v_titanBouncingOrbAttack(args)
  local rq = vBehavior.requireArgsGen("v_titanBouncingOrbAttack", args)
  if not rq{"projectileCount", "projectileType", "flickDelay", "flickInterval", "flickCount", "target"} then
    return false
  end

  local params = copy(args.projectileParameters or {})
  params.power = vAttack.scaledPower(params.power or 10)

  -- Get eye positions.
  local leftEyePos = vec2.add(animator.partPoint("body", "leftEyeCenter"), mcontroller.position())
  local rightEyePos = vec2.add(animator.partPoint("body", "rightEyeCenter"), mcontroller.position())

  local projectiles = {}

  -- Spawn projectiles at left eye
  for i = 1, args.projectileCount do
    local angle = 2 * math.pi * i / args.projectileCount
    local id = world.spawnProjectile(args.projectileType, leftEyePos, entity.id(), vec2.withAngle(angle), false, params)
    table.insert(projectiles, id)
  end

  -- Spawn projectiles at right eye
  for i = 1, args.projectileCount do
    local angle = 2 * math.pi * i / args.projectileCount
    local id = world.spawnProjectile(args.projectileType, rightEyePos, entity.id(), vec2.withAngle(angle), false, params)
    table.insert(projectiles, id)
  end

  util.run(args.flickDelay, function() end)

  local targetPos = world.entityPosition(args.target)
  local maxAttempts = 200

  -- Flick random projectiles toward the player.
  for _ = 1, args.flickCount do
    -- Attempt to select next projectile (must be in the line of sight of the player)
    local nextIdx
    local attempts = 0
    repeat
      nextIdx = math.random(1, #projectiles)
      attempts = attempts + 1
    until attempts > maxAttempts or not world.entityExists(projectiles[nextIdx]) or not world.lineCollision(targetPos, world.nearestTo(targetPos, world.entityPosition(projectiles[nextIdx])))

    -- If the loop above exited because a valid choice was found...
    if attempts <= maxAttempts and world.entityExists(projectiles[nextIdx]) then
      -- Trigger the projectile to fly towards the player.
      vWorld.sendEntityMessage(projectiles[nextIdx], "v-titanbouncingprojectile-fling", args.target)

      -- Delete projectile from list
      table.remove(projectiles, nextIdx)
    end

    util.run(args.flickInterval, function() end)
  end

  return true
end