require "/scripts/util.lua"
require "/scripts/vec2.lua"
require "/scripts/v-attack.lua"
require "/scripts/actions/flying.lua"
require "/scripts/v-world.lua"

local debugSearchZones

local oldUpdate = update or function() end
function update(dt)
  oldUpdate(dt)

  if debugSearchZones then
    for i, zone in ipairs(debugSearchZones) do
      local startPos = mcontroller.position()
      if zone.sweep then
        for _, angle in ipairs(zone.debugCluster) do
          world.debugLine(startPos, vec2.add(startPos, vec2.withAngle(angle, 20)), "yellow")
        end
        world.debugLine(startPos, vec2.add(startPos, vec2.withAngle(zone.startAngle, 20)), "orange")
        world.debugLine(startPos, vec2.add(startPos, vec2.withAngle(zone.endAngle, 20)), "blue")
        world.debugText("#%s start", i, vec2.add(startPos, vec2.withAngle(zone.startAngle, 20)), "orange")
        world.debugText("#%s end", i, vec2.add(startPos, vec2.withAngle(zone.endAngle, 20)), "blue")
      else
        for _, angle in ipairs(zone.debugCluster) do
          world.debugLine(startPos, vec2.add(startPos, vec2.withAngle(angle, 20)), "red")
        end
        world.debugText("#%s", i, vec2.add(startPos, vec2.withAngle(zone.angle, 20)), "green")
        world.debugLine(startPos, vec2.add(startPos, vec2.withAngle(zone.angle, 20)), "green")
      end
    end
  end
end

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

  -- animator.resetTransformationGroup("lefteye")
  -- animator.resetTransformationGroup("righteye")
  -- animator.rotateTransformationGroup("lefteye", leftEyeStartAngle, leftEyeCenter)
  -- animator.rotateTransformationGroup("righteye", rightEyeStartAngle, rightEyeCenter)
  v_titanRotateEyes{ leftEyeAngle = leftEyeStartAngle, rightEyeAngle = rightEyeStartAngle }

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
    -- animator.resetTransformationGroup("lefteye")
    -- animator.resetTransformationGroup("righteye")
    -- animator.rotateTransformationGroup("lefteye", leftEyeAngle, leftEyeCenter)
    -- animator.rotateTransformationGroup("righteye", rightEyeAngle, rightEyeCenter)
    v_titanRotateEyes{ leftEyeAngle = leftEyeAngle, rightEyeAngle = rightEyeAngle }

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

-- param target
function v_titanSearch(args)
  local rq = vBehavior.requireArgsGen("v_titanSearch", args)

  if not rq{"target"} then return false end

  local angularVelocity = 2 * math.pi  -- Parameter
  local rayCount = 40  -- Parameter
  local maxRaycastLength = 100  -- Parameter
  local turnWaitTime = 0.5

  local flyTolerance = 8
  local flySpeed = 10
  local flyControlForce = 6

  ---@param startAngle number
  ---@param endAngle number
  local turn = function(startAngle, endAngle)
    local timer = 0
    local dt = script.updateDt()
    local interpEndAngle = startAngle + util.angleDiff(startAngle, endAngle)
    local turnTime = math.abs(startAngle - interpEndAngle) / angularVelocity

    while timer < turnTime do
      local curAngle = util.lerp(timer / turnTime, startAngle, interpEndAngle)
      timer = timer + dt
      world.debugLine(mcontroller.position(), vec2.add(mcontroller.position(), vec2.withAngle(curAngle, 20)), "blue")

      coroutine.yield(nil, {angle = curAngle})
    end
  end

  local currentAngle = args.startAngle or -math.pi / 2
  while true do
    local searchZones = processRaycastClusters(radialRaycast(mcontroller.position(), rayCount, maxRaycastLength))

    debugSearchZones = searchZones

    -- Go through each search zone.
    for _, zone in ipairs(searchZones) do
      -- A sweep turns to the start angle, then the end angle, then the start angle again.
      if zone.sweep then
        turn(currentAngle, zone.startAngle)
        turn(zone.startAngle, zone.endAngle)
        -- wait(turnWaitTime, zone.endAngle)
        util.run(turnWaitTime, function() end)
        -- wait(turnWaitTime, zone.startAngle)
        turn(zone.endAngle, zone.startAngle)
        util.run(turnWaitTime, function() end)

        currentAngle = zone.startAngle
      else
        -- A spot turns to the angle
        turn(currentAngle, zone.angle)
        -- wait(turnWaitTime, zone.angle)
        util.run(turnWaitTime, function() end)

        currentAngle = zone.angle
      end
    end

    -- debugSearchZones = nil

    -- local searchPoint = findNextSearchPoint(searchZones)
    -- local adjustedSearchPoint = centerOfRadialRaycast(searchPoint, rayCount, maxRaycastLength)
    -- -- searchPoint and adjustedSearchPoint are, themselves, prone to error. Maybe get the midpoint of them?
    -- local targetPos = {(searchPoint[1] + adjustedSearchPoint[1]) / 2, (searchPoint[2] + adjustedSearchPoint[2]) / 2}

    local targetOffsetRegion = {-30, -30, 30, 30}
    local requiredSafeRegion = {-2, -2, 2, 2}
    local maxAttempts = 10
    local targetPos = world.entityPosition(args.target)
    local nextPos = findRandomAirPosition(maxAttempts, targetPos, targetOffsetRegion, requiredSafeRegion, 1, 20)

    if not nextPos then
      return false
    end

    turn(currentAngle, vec2.angle(world.distance(nextPos, mcontroller.position())))

    -- Fly to target position
    local distance
    repeat
      distance = world.distance(nextPos, mcontroller.position())

      mcontroller.controlApproachVelocity(vec2.mul(vec2.norm(distance), flySpeed), flyControlForce)

      currentAngle = vec2.angle(distance)

      coroutine.yield(nil, {angle = currentAngle})
    until math.abs(distance[1]) < flyTolerance and math.abs(distance[2]) < flyTolerance

    -- Stop
    while vec2.mag(mcontroller.velocity()) > 0 do
      mcontroller.controlApproachVelocity({0, 0}, flyControlForce)
      coroutine.yield()
    end

    -- Try to find a path
    local pathfindResults = world.findPlatformerPath(mcontroller.position(), world.entityPosition(args.target), mcontroller.baseParameters(), {
      returnBest = false,
      mustEndOnGround = false,
      maxFScore = 400,
      maxDistance = 200,
      maxNodesToSearch = 70000,
      boundBox = mcontroller.boundBox()
    })

    -- Fail if no path to the player is found.
    if not pathfindResults then
      return false
    end
  end
end

-- param leftEyeAngle
-- param rightEyeAngle
-- param position
-- param target
function v_titanRotateEyes(args)
  if not ((args.leftEyeAngle and args.rightEyeAngle) or args.target or args.position) then
    sb.logWarn("v_titanRotateEyes: Requires 'leftEyeAngle' and 'rightEyeAngle', 'target', or 'position' to be defined arguments")
    return false
  end

  local leftEyeCenter = animator.partPoint("body", "leftEyeCenter")
  local rightEyeCenter = animator.partPoint("body", "rightEyeCenter")
  local leftPupilLookRadius = animator.partProperty("leftpupil", "lookRadius")
  local rightPupilLookRadius = animator.partProperty("rightpupil", "lookRadius")
  local targetPos
  -- If the target is provided...
  if args.target then
    targetPos = world.entityPosition(args.target)
  elseif args.position then
    targetPos = args.position
  end

  local leftEyeAngle, rightEyeAngle
  -- If a position is given or derived...
  if targetPos then
    local leftEyePos = vec2.add(mcontroller.position(), leftEyeCenter)
    local rightEyePos = vec2.add(mcontroller.position(), rightEyeCenter)
    leftEyeAngle = vec2.angle(world.distance(targetPos, leftEyePos))
    rightEyeAngle = vec2.angle(world.distance(targetPos, rightEyePos))
  else
    leftEyeAngle = args.leftEyeAngle
    rightEyeAngle = args.rightEyeAngle
  end

  animator.resetTransformationGroup("lefteye")
  animator.resetTransformationGroup("righteye")
  animator.rotateTransformationGroup("lefteye", leftEyeAngle, leftEyeCenter)
  animator.rotateTransformationGroup("righteye", rightEyeAngle, rightEyeCenter)

  animator.resetTransformationGroup("leftpupil")
  animator.resetTransformationGroup("rightpupil")
  animator.translateTransformationGroup("leftpupil", vec2.withAngle(leftEyeAngle, leftPupilLookRadius))
  animator.translateTransformationGroup("rightpupil", vec2.withAngle(rightEyeAngle, rightPupilLookRadius))

  return true
end

function v_titanDetectTarget(args)
  local rq = vBehavior.requireArgsGen("v_titanDetectTarget", args)

  if not rq{"currentAngle"} then return false end

  local sightRadius = 25
  local halfFov = util.toRadians(45) / 2
  local exposureTime = 0.25
  local queriedTimings = {}

  local isValidTarget = function(target, eyePos)
    if world.entityExists(target) then
      local targetPos = world.entityPosition(target)
      return not (world.lineTileCollision(eyePos, world.nearestTo(eyePos, targetPos)) or world.magnitude(eyePos, targetPos) > sightRadius)
    end

    return false
  end

  local updateQueried = function(qItem)
    if queriedTimings[qItem] then
      queriedTimings[qItem] = queriedTimings[qItem] - script.updateDt()
    else
      queriedTimings[qItem] = exposureTime
    end
  end

  local getTarget = function(eyePos)
    local queried = world.entityQuery(eyePos, sightRadius, {withoutEntityId = entity.id(), includedTypes = {"player"}})
    -- Iterate through each queried entity. Find the first one that is within its field of view (ordered from nearest to farthest)
    for _, qItem in pairs(queried) do
      local sightCloseness = math.abs(
        util.angleDiff(
          args.currentAngle,
          vec2.angle(world.distance(world.entityPosition(qItem), eyePos))
        )
      )
      if isValidTarget(qItem, eyePos) and sightCloseness <= halfFov then
        updateQueried(qItem)
        if queriedTimings[qItem] < 0 then
          return qItem
        end
      else
        queriedTimings[qItem] = nil
      end
    end
  end

  local target
  while not target do
    target = getTarget(vec2.add(mcontroller.position(), animator.partPoint("body", "leftEyeCenter")))
    or getTarget(vec2.add(mcontroller.position(), animator.partPoint("body", "rightEyeCenter")))

    world.debugText("queriedTimings: %s", queriedTimings, mcontroller.position(), "green")

    coroutine.yield()
  end

  return true
end

-- param target
function v_titanGrab(args)
  local rq = vBehavior.requireArgsGen("v_titanGrab", args)

  if not rq{"target"} then return false end

  local armSpawnRegion = {-10, -10, 10, 10}
  local requiredSafeArea = {-2, -2, 2, 2}
  local maxAttempts = 200

  -- Pick a random arm spawning position. Abort after `maxAttempts` attempts
  local spawnPos
  local attempts = 0
  repeat
    spawnPos = vec2.add(mcontroller.position(), rect.randomPoint(armSpawnRegion))
    attempts = attempts + 1
  until (not world.lineCollision(mcontroller.position(), spawnPos) and not world.rectCollision(rect.translate(requiredSafeArea, spawnPos))) or attempts > maxAttempts

  -- If no arm spawning position is available, fail.
  if attempts > maxAttempts then return false end

  local anchorPoint = vec2.add(mcontroller.position(), vec2.withAngle(math.random() * 2 * math.pi, 10))
  -- Spawn the arm
  world.spawnMonster("v-titanofdarknessarm", spawnPos, {task = "grab", taskArguments = {target = args.target}, master = entity.id(), anchorPoint = anchorPoint})

  -- Look at arm position.
  coroutine.yield(nil, {angle = vec2.angle(world.distance(spawnPos, mcontroller.position()))})

  -- Wait for arm to finish.
  vBehavior.awaitNotification("v-titanofdarkness-armFinished")

  -- Inspect contents.
  util.run(0.5, function() end)

  return true
end

---@param searchZones (SpotSearchZone | SweepSearchZone)[]
---@param target EntityId
---@return Vec2F?
function findNextSearchPoint(searchZones, target)
  local pathfindMaxLookahead = 3  -- Preferred index of choice when choosing an element from pathfindResults.
  local pathfindResults = world.findPlatformerPath(mcontroller.position(), world.entityPosition(target), mcontroller.baseParameters(), {
    returnBest = false,
    mustEndOnGround = false,
    maxFScore = 400,
    maxDistance = 200,
    maxNodesToSearch = 70000,
    boundBox = mcontroller.boundBox()
  })

  -- Return nothing if no path to the player is found.
  if not pathfindResults then
    return nil
  end
  local targetOffsetRegion = {-30, -30, 30, 30}
  local requiredSafeRegion = {-2, -2, 2, 2}
  local maxAttempts = 10
  local targetPos = world.entityPosition(target)
  return findRandomAirPosition(maxAttempts, targetPos, targetOffsetRegion, requiredSafeRegion, 1, 20)
end

---Returns the average of the positions resulting from a radial raycast of `rayCount` rays at position `position`, with
---rays that are more parallel to the given angle having less weight than those that are perpendicular to it.
---@param position Vec2F
---@param angle number
---@param rayCount integer
---@param maxRaycastLength number
---@return Vec2F
function adjustAgainstGeometry(position, angle, rayCount, maxRaycastLength)
  local positionSum = {0, 0}

  -- For each ray...
  for i = 0, rayCount - 1 do
    local rayAngle = 2 * math.pi * i / rayCount  -- Calculate angle.
    local endPos = vec2.add(position, vec2.withAngle(rayAngle, maxRaycastLength))  -- Calculate end position
    local raycast = world.lineCollision(position, endPos)  -- Perform collision test

    local weight = math.abs(math.sin(util.angleDiff(rayAngle, angle)))  -- Calculate weight
    -- Apply weight to raycast or endPos, whichever is defined.
    local weightedPosition = vec2.add(vec2.mul(world.distance(raycast or endPos, position), weight), position)
    -- Add to the sum of positions
    positionSum = vec2.add(positionSum, weightedPosition)
  end

  -- Divide this sum by the number of positions (rayCount)
  return vec2.mul(positionSum, 1 / rayCount)
end

---@param position Vec2F
---@param rayCount integer
---@param maxRaycastLength number
---@return number[][]
function radialRaycast(position, rayCount, maxRaycastLength)
  -- Find locations of tunnels by raycasting around the entity. Wherever there are changes in raycast distance that exceed
  -- a threshold, these are tunnels. Massive increase in distance followed by a massive decrease in distance => a cluster.
  -- Break it all up into contiguous blocks with these markers. If the blocks occupy a certain amount of vision, then use
  -- a sweep. Otherwise, stop in the middle of the block.
  -- A sweep consists of a start angle and an end angle.
  local searchThreshold = 20  -- The minimum raycast distance necessary to add a search region. Parameter

  local raycastClusters = {}
  local nextRaycastCluster = {}
  local firstRaycastAdded = false
  local lastRaycastAdded = false

  for i = 0, rayCount - 1 do
    local angle = 2 * math.pi * i / rayCount

    local raycastDistance
    -- Attempt raycast
    local raycast = world.lineCollision(position, vec2.add(position, vec2.withAngle(angle, maxRaycastLength)))
    if raycast then
      raycastDistance = world.magnitude(position, raycast)
    else
      raycastDistance = maxRaycastLength
    end

    -- If the raycast distance goes below the threshold and we are adding to the raycast cluster...
    if raycastDistance < searchThreshold and #nextRaycastCluster > 0 then
      table.insert(raycastClusters, nextRaycastCluster)  -- Push the next raycast cluster to the list.
      nextRaycastCluster = {}  -- Clear nextRaycastCluster list
    end

    -- If the raycast distance exceeds the threshold or we are adding to the raycast cluster...
    if raycastDistance > searchThreshold or #nextRaycastCluster > 0 then
      -- If this is the first raycast...
      if i == 1 then
        firstRaycastAdded = true  -- Mark as added.
      -- Otherwise, if this is the last raycast...
      elseif i == rayCount then
        lastRaycastAdded = true  -- Mark as added.
      end

      table.insert(nextRaycastCluster, angle)  -- Add to the next raycast cluster
    end
  end

  -- If there are some angles in the next cluster remaining...
  if #nextRaycastCluster > 0 then
    -- If the first angle and the last angle were added to a cluster...
    if firstRaycastAdded and lastRaycastAdded then
      -- Copy everything in the next raycast cluster to the beginning of the first cluster.
      for _, angle in ipairs(nextRaycastCluster) do
        table.insert(raycastClusters[1], 1, angle)
      end
    else
      table.insert(raycastClusters, nextRaycastCluster)
    end
  end
  return raycastClusters
end

---@class SpotSearchZone
---@field sweep false
---@field angle number

---@class SweepSearchZone
---@field sweep true
---@field startAngle number
---@field endAngle number

---@param raycastClusters any
---@return (SpotSearchZone | SweepSearchZone)[]
function processRaycastClusters(raycastClusters)
  -- Returns a sequence of sweep and spot searches.

  -- Entries in each cluster must be sorted.

  -- The minimum angular span of a raycast cluster necessary for it to become a sweep search instead of a spot search.
  local sweepThreshold = 2 * math.pi * 0.2  -- Parameter
  -- A sweep search consists of sweeping back and forth once.
  -- A spot search consists of turning toward the center of the search zone and stopping for a brief moment.

  local searchZones = {}
  for _, cluster in ipairs(raycastClusters) do
    -- If the angular span of the cluster exceeds the sweep threshold...
    if math.abs(util.angleDiff(cluster[1], cluster[#cluster])) > sweepThreshold then
      -- Mark as a sweep.
      table.insert(searchZones, {sweep = true, startAngle = cluster[1], endAngle = cluster[#cluster], debugCluster = cluster})
    else
      -- Compute midpoint between the two edge angles of the cluster.
      local middleAngle = (cluster[1] + cluster[#cluster]) / 2
      table.insert(searchZones, {sweep = false, angle = middleAngle, debugCluster = cluster})
    end
  end

  return searchZones
end

---Chooses a random position in `initialSelectionArea` centered at `center` and then runs findAirPosition on the center.
---@param maxAttempts integer
---@param center Vec2F
---@param initialSelectionArea RectF
---@param requiredSafeArea RectF
---@param lerpStep integer
---@param maxDistance number
---@return Vec2F?
function findRandomAirPosition(maxAttempts, center, initialSelectionArea, requiredSafeArea, lerpStep, maxDistance)
  local nextPos
  local attempts = 0

  -- While a position has not been found yet and less than maxAttempts have been made...
  while not nextPos and attempts < maxAttempts do
    -- Choose random position within a rectangle
    local candidate = vec2.add(center, rect.randomPoint(initialSelectionArea))
    -- Find a corresponding air position
    local status, results = findAirPosition{centerPosition = candidate, collisionArea = requiredSafeArea, maxDistance = 20, lerpStep = 1.0}
    if status then
      -- Tell LuaLS to disregard results potentially being nil.
      ---@diagnostic disable: need-check-nil
      nextPos = results.position
    end
    attempts = attempts + 1
  end

  -- If the above loop stopped because more than maxAttempts attempts have been made...
  if attempts >= maxAttempts then
    return nil  -- Stop and return nothing
  end

  return nextPos
end