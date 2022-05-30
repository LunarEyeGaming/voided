require "/scripts/util.lua"
require "/scripts/vec2.lua"

-- Overengineered, but it works
UniqueRand = {}
function UniqueRand:new()
  local instance = {}
  instance.prevValue = nil
  setmetatable(instance, {__index = self})
  return instance
end

function UniqueRand:randInt(min, max)
  local res
  repeat
    res = math.random(min, max)
    --sb.logInfo("%s ?= %s", self.prevValue, res)
  until res ~= self.prevValue
  --sb.logInfo("self.prevValue: %s", self.prevValue)
  --sb.logInfo("res: %s", res)
  self.prevValue = res
  return res
end

-- param nRows
-- param nCols
-- param coreIds
-- param corePositions
-- output coreIds, corePositions
-- Randomly partition the cores by phase such that at least one core is active in every row in every phase. Pre-condition: nCols = the number of phases
function v_partitionCores(args, board)
  math.randomseed(os.time())
  local phaseMatrix = {}
  local resIds = {}
  local resPositions = {}
  for i = 1, args.nRows do
    phaseMatrix[i] = {}
    for j = 1, args.nCols do
      table.insert(phaseMatrix[i], j)
    end
    shuffle(phaseMatrix[i])
  end

  for i, row in ipairs(phaseMatrix) do
    for j, phase in ipairs(row) do
      if not resIds[phase] then
        resIds[phase] = {}
      end
      if not resPositions[phase] then
        resPositions[phase] = {}
      end
      table.insert(resIds[phase], args.coreIds[(i - 1) * args.nCols + j])  -- TODO: Verify that this indexing works.
      table.insert(resPositions[phase], args.corePositions[(i - 1) * args.nCols + j])
    end
  end

  return true, {coreIds = resIds, corePositions = resPositions}
end

-- param laserH1Offset
-- param laserV1Offset
-- param laserH2Offset
-- param laserV2Offset
-- param coreXOffsets
-- param coreYOffsets
-- output laserH1Id, laserV1Id, laserH2Id, laserV2Id, coreIds, corePositions
function v_spawnStrongholdParts(args, board)
  local laserIds = {}
  local coreIds = {}
  local corePositions = {}

  local center = mcontroller.position()

  local laserH1Id = world.spawnMonster(
    "v-strongholdbosslaserhorizontal",
    vec2.add(center, args.laserH1Offset),
    {level = monster.level(), masterId = entity.id()}
  )
  local laserH2Id = world.spawnMonster(
    "v-strongholdbosslaserhorizontal2",
    vec2.add(center, args.laserH2Offset),
    {level = monster.level(), masterId = entity.id()}
  )
  local laserV1Id = world.spawnMonster(
    "v-strongholdbosslaservertical",
    vec2.add(center, args.laserV1Offset),
    {level = monster.level(), masterId = entity.id()}
  )
  local laserV2Id = world.spawnMonster(
    "v-strongholdbosslaservertical2",
    vec2.add(center, args.laserV2Offset),
    {level = monster.level(), masterId = entity.id()}
  )

  for i = 1, #args.coreXOffsets do
    for j = 1, #args.coreYOffsets do
      local corePosition = vec2.add(center, {args.coreXOffsets[i], args.coreYOffsets[j]})
      local coreId = world.spawnMonster("v-strongholdbosscore", corePosition, {level = monster.level()})
      table.insert(coreIds, coreId)
      table.insert(corePositions, corePosition)
    end
  end

  return true, {
    laserH1Id = laserH1Id,
    laserV1Id = laserV1Id,
    laserH2Id = laserH2Id,
    laserV2Id = laserV2Id,
    coreIds = coreIds,
    corePositions = corePositions
  }
end

-- param coreXOffsets
-- param coreYOffsets
-- output coreIds, corePositions
function v_spawnStrongholdParts2(args, board)
  local coreIds = {}
  local corePositions = {}

  --laserH1Offset = {-18, 0}
  --laserV1Offset = {0, 15}

  local center = mcontroller.position()

  --local nRows = 3
  --local nCols = 3
  --local coreXOffsets = {-14, 0, 14}
  --local coreYOffsets = {-11, 0, 11}

  for i = 1, #args.coreXOffsets do
    for j = 1, #args.coreYOffsets do
      local corePosition = vec2.add(center, {args.coreXOffsets[i], args.coreYOffsets[j]})
      local coreId = world.spawnMonster("v-strongholdbosscore", corePosition, {level = monster.level()})
      table.insert(coreIds, coreId)
      table.insert(corePositions, corePosition)
    end
  end

  return true, {coreIds = coreIds, corePositions = corePositions}
end

-- param h1Id
-- param v1Id
-- param h2Id
-- param v2Id
-- param hOffsets
-- param vOffsets
-- param hTeleProjectile
-- param vTeleProjectile
-- param loops
-- param phase
-- param waitTime
function v_laserAttack(args, board)
  local center = mcontroller.position()
  local randGenH = UniqueRand:new()
  local randGenV = UniqueRand:new()
  local activeLasers = args.phase + 1
  for i = 1, args.loops do
    local hId = i % 2 == 0 and args.h1Id or args.h2Id
    local vId = i % 2 == 0 and args.v1Id or args.v2Id

    local hPosition = vec2.add(center, util.randomFromList(args.hOffsets, randGenH))
    local vPosition = vec2.add(center, util.randomFromList(args.vOffsets, randGenV))

    world.spawnProjectile(args.hTeleProjectile, hPosition)
    world.spawnProjectile(args.vTeleProjectile, vPosition)

    world.sendEntityMessage(hId, "move", hPosition)
    world.sendEntityMessage(vId, "move", vPosition)

    -- Activate an extra laser in phase 2
    local extraId1  -- Need to keep this variable for later
    if args.phase >= 2 then
      extraId1 = i % 2 == 0 and args.h2Id or args.v1Id  -- Alternate between two horizontal lasers active at once and two vertical lasers active at once
      local extraOffsets = i % 2 == 0 and args.hOffsets or args.vOffsets
      local extraRandGen = i % 2 == 0 and randGenH or randGenV
      local extraPosition = vec2.add(center, util.randomFromList(extraOffsets, extraRandGen))
      local extraTeleProjectile = i % 2 == 0 and args.hTeleProjectile or args.vTeleProjectile
      world.spawnProjectile(extraTeleProjectile, extraPosition)
      world.sendEntityMessage(extraId1, "move", extraPosition)
    end

    -- And another one in phase 3
    local extraId2  -- Need to keep this variable too
    if args.phase == 3 then
      extraId2 = i % 2 == 0 and args.v2Id or args.h1Id
      local extraOffsets = i % 2 == 0 and args.vOffsets or args.hOffsets
      local extraRandGen = i % 2 == 0 and randGenV or randGenH
      local extraPosition = vec2.add(center, util.randomFromList(extraOffsets, extraRandGen))
      local extraTeleProjectile = i % 2 == 0 and args.vTeleProjectile or args.hTeleProjectile
      world.spawnProjectile(extraTeleProjectile, extraPosition)
      world.sendEntityMessage(extraId2, "move", extraPosition)
    end

    --sb.logInfo("IDs: %s, %s, %s, %s", hId, vId, extraId1, extraId2)

    _v_awaitNotification("finished", activeLasers)

    world.sendEntityMessage(hId, "pulse")
    world.sendEntityMessage(vId, "pulse")
    if args.phase >= 2 then
      world.sendEntityMessage(extraId1, "pulse")
    end

    if args.phase == 3 then
      world.sendEntityMessage(extraId2, "pulse")
    end

    _v_awaitNotification("finished", activeLasers)

    util.run(args.waitTime, function() end)
  end

  world.sendEntityMessage(args.h1Id, "reset")
  world.sendEntityMessage(args.h2Id, "reset")
  world.sendEntityMessage(args.v1Id, "reset")
  world.sendEntityMessage(args.v2Id, "reset")

  _v_awaitNotification("finished", 4)

  return true
end

-- param h1Id - Left horizontal laser entity ID
-- param v1Id - Top vertical laser entity ID
-- param h2Id - Right horizontal laser entity ID
-- param v2Id - Bottom vertical laser entity ID
-- param h1Offsets
-- param v1Offsets
-- param h2Offsets
-- param v2Offsets
-- param hTeleProjectile
-- param vTeleProjectile
-- param waitTime
function v_laserAttack2(args, board)
  local center = mcontroller.position()
  local useFourLasers = args.h2Offsets and args.v2Offsets
  for i = 1, #args.h1Offsets do
    local h1Position = vec2.add(center, args.h1Offsets[i])
    local v1Position = vec2.add(center, args.v1Offsets[i])
    local h2Position
    local v2Position
    if useFourLasers then
      h2Position = vec2.add(center, args.h2Offsets[i])
      v2Position = vec2.add(center, args.v2Offsets[i])
    end

    world.spawnProjectile(args.hTeleProjectile, h1Position)
    world.spawnProjectile(args.vTeleProjectile, v1Position)
    if useFourLasers then
      world.spawnProjectile(args.hTeleProjectile, h2Position)
      world.spawnProjectile(args.vTeleProjectile, v2Position)
    end

    world.sendEntityMessage(args.h1Id, "move", h1Position)
    world.sendEntityMessage(args.v1Id, "move", v1Position)
    if useFourLasers then
      world.sendEntityMessage(args.h2Id, "move", h2Position)
      world.sendEntityMessage(args.v2Id, "move", v2Position)
    end

    if useFourLasers then
      _v_awaitNotification("finished", 4)
    else
      _v_awaitNotification("finished", 2)
    end

    world.sendEntityMessage(args.h1Id, "pulse")
    world.sendEntityMessage(args.v1Id, "pulse")
    if useFourLasers then
      world.sendEntityMessage(args.h2Id, "pulse")
      world.sendEntityMessage(args.v2Id, "pulse")
    end

    if useFourLasers then
      _v_awaitNotification("finished", 4)
    else
      _v_awaitNotification("finished", 2)
    end

    util.run(args.waitTime, function() end)
  end

  world.sendEntityMessage(args.h1Id, "reset")
  world.sendEntityMessage(args.v1Id, "reset")
  if useFourLasers then
    world.sendEntityMessage(args.h2Id, "reset")
    world.sendEntityMessage(args.v2Id, "reset")
  end

  if useFourLasers then
    _v_awaitNotification("finished", 4)
  else
    _v_awaitNotification("finished", 2)
  end

  return true
end

-- param attackSet
  -- field idKey
  -- field startOffset
  -- field endOffset
  -- field teleOffset
  -- field teleProjectile
-- param sampleSize
-- param waitTime
function v_laserAttack3(args, board)
  local center = mcontroller.position()
  local attackSet = copy(args.attackSet)
  shuffle(attackSet)

  for i, attack in ipairs(attackSet) do
    if i > args.sampleSize then
      break
    end
    local id = board:getEntity(attack.idKey)
    local startPosition = vec2.add(center, attack.startOffset)
    local endPosition = vec2.add(center, attack.endOffset)

    world.spawnProjectile(attack.teleProjectile, vec2.add(center, attack.teleOffset))

    world.sendEntityMessage(id, "move", startPosition)
    _v_awaitNotification("finished")

    world.sendEntityMessage(id, "activate")
    _v_awaitNotification("finished")

    world.sendEntityMessage(id, "move", endPosition)
    _v_awaitNotification("finished")

    world.sendEntityMessage(id, "deactivate")
    _v_awaitNotification("finished")

    util.run(args.waitTime, function() end)
  end

  for _, attack in ipairs(args.attackSet) do
    local id = board:getEntity(attack.idKey)
    world.sendEntityMessage(id, "reset")
  end

  _v_awaitNotification("finished", #args.attackSet)

  return true
end

-- param h1Id
-- param v1Id
-- param h2Id
-- param v2Id
-- param hBounds - Lower bound and upper bound, respectively, of the vertical positions that horizontal lasers can move to.
-- param vBounds - Lower and upper bounds, respectively, of the horizontal positions that vertical lasers can move to.
-- param loops
-- param target
-- param targetProjectile
-- param phase3WarningProjectile
-- param phase
-- param waitTime
function v_laserAttack4(args, board)
  local center = mcontroller.position()

  local hPosBounds = {center[2] + args.hBounds[1], center[2] + args.hBounds[2]}
  local vPosBounds = {center[1] + args.vBounds[1], center[1] + args.vBounds[2]}
  
  if args.phase == 3 then
    world.spawnProjectile(args.phase3WarningProjectile, mcontroller.position(), entity.id(), {0, 0})
    util.run(args.phase3WarningTime, function() end)
  end

  for i = 1, args.loops do
    local targetPos = _getCappedTargetPos(args.target, hPosBounds, vPosBounds)

    local hId = i % 2 == 0 and args.h1Id or args.h2Id
    local vId = i % 2 == 0 and args.v1Id or args.v2Id

    if args.phase == 1 then
      world.spawnProjectile(args.targetProjectile, targetPos, entity.id(), {0, 0})
      world.sendEntityMessage(hId, "move", targetPos)
      world.sendEntityMessage(vId, "move", targetPos)

      _v_awaitNotification("finished", 2)

      world.sendEntityMessage(hId, "pulse")
      world.sendEntityMessage(vId, "pulse")

      _v_awaitNotification("finished", 2)
    elseif args.phase == 2 then

      world.spawnProjectile(args.targetProjectile, targetPos, entity.id(), {0, 0})
      world.sendEntityMessage(hId, "moveandpulse", targetPos)
      util.run(args.waitTime, function() end)

      targetPos = _getCappedTargetPos(args.target, hPosBounds, vPosBounds)
      world.spawnProjectile(args.targetProjectile, targetPos, entity.id(), {0, 0})
      world.sendEntityMessage(vId, "moveandpulse", targetPos)
    elseif args.phase == 3 then
      world.spawnProjectile(args.targetProjectile, targetPos, entity.id(), {0, 0})

      world.sendEntityMessage(hId, "move", targetPos)
      world.sendEntityMessage(vId, "move", targetPos)
      _v_awaitNotification("finished", 2)

      world.sendEntityMessage(hId, "activate")
      world.sendEntityMessage(vId, "activate")
      _v_awaitNotification("finished", 2)

      util.run(0.5, function() end)

      targetPos = _getCappedTargetPos(args.target, hPosBounds, vPosBounds)

      world.spawnProjectile(args.targetProjectile, targetPos, entity.id(), {0, 0})

      world.sendEntityMessage(hId, "move", targetPos)
      world.sendEntityMessage(vId, "move", targetPos)
      _v_awaitNotification("finished", 2)

      world.sendEntityMessage(hId, "deactivate")
      world.sendEntityMessage(vId, "deactivate")
      _v_awaitNotification("finished", 2)
    end

    util.run(args.waitTime, function() end)
  end

  world.sendEntityMessage(args.h1Id, "reset")
  world.sendEntityMessage(args.v1Id, "reset")
  world.sendEntityMessage(args.h2Id, "reset")
  world.sendEntityMessage(args.v2Id, "reset")

  _v_awaitNotification("finished", 4)

  return true
end

-- param attackSet
  -- field idKey
  -- field startOffset
  -- field endOffset
  -- field teleOffset
  -- field teleProjectile
-- param waitTime
function v_laserAttack5(args, board)
  local center = mcontroller.position()

  -- Very hacky way of implementation. TODO: Clean up this code
  for i, attack in ipairs(args.attackSet) do
    local id = board:getEntity(attack.idKey)
    local startPosition = vec2.add(center, attack.startOffset)
    local endPosition = vec2.add(center, attack.endOffset)

    world.sendEntityMessage(id, "move", startPosition)
  end

  _v_awaitNotification("finished", #args.attackSet)
  
  for i, attack in ipairs(args.attackSet) do
    local id = board:getEntity(attack.idKey)

    world.spawnProjectile(attack.teleProjectile, vec2.add(center, attack.teleOffset))

    world.sendEntityMessage(id, "activate")
    _v_awaitNotification("finished")
  end

  util.run(args.waitTime, function() end)
  util.run(args.waitTime, function() end)

  for i, attack in ipairs(args.attackSet) do
    local id = board:getEntity(attack.idKey)
    local startPosition = vec2.add(center, attack.startOffset)
    local endPosition = vec2.add(center, attack.endOffset)

    world.sendEntityMessage(id, "move", endPosition)
  end

  util.run(args.waitTime, function() end)
  util.run(args.waitTime, function() end)

  for i, attack in ipairs(args.attackSet) do
    local id = board:getEntity(attack.idKey)

    world.sendEntityMessage(id, "deactivate")
  end

  util.run(args.waitTime, function() end)

  for _, attack in ipairs(args.attackSet) do
    local id = board:getEntity(attack.idKey)
    world.sendEntityMessage(id, "reset")
  end

  _v_awaitNotification("finished", #args.attackSet)

  return true
end

-- param h1Id
-- param v1Id
-- param h2Id
-- param v2Id
function v_resetLasers(args, board)
  world.sendEntityMessage(args.h1Id, "reset")
  world.sendEntityMessage(args.v1Id, "reset")
  world.sendEntityMessage(args.h2Id, "reset")
  world.sendEntityMessage(args.v2Id, "reset")
  _v_awaitNotification("finished", 4)

  return true
end

-- param coreIds  -- DEPRECATED
-- param nResults  -- DEPRECATED
-- param corePartition
-- param corePositionPartition
-- param phase
-- output coreIds
function v_activateCores(args, board)
  -- local randGen = UniqueRand:new()
  -- local selected = {}

  -- for i = 1, args.nResults do
    -- local coreId = util.randomFromList(args.coreIds, randGen)
    -- table.insert(selected, coreId)
    -- world.sendEntityMessage(coreId, "notify", {
      -- sourceId = entity.id(),
      -- type = "activate"
    -- })
  -- end
  local selected = args.corePartition[args.phase]
  local selectedPositions = args.corePositionPartition[args.phase]
  for _, id in ipairs(selected) do
    world.sendEntityMessage(id, "notify", {
      sourceId = entity.id(),
      type = "activate"
    })
  end

  return true, {coreIds = selected, corePositions = selectedPositions}
end

-- param lightIds
-- param intensities
-- param coreCount
-- param prevCoreCount
-- param duration
function v_flickerLights(args, board)
  if args.prevCoreCount <= args.coreCount then return false end
  animator.playSound("flicker")
  for _, id in ipairs(args.lightIds) do
    world.sendEntityMessage(id, "flicker", args.intensities[args.coreCount + 1], args.duration)
  end
  
  return true
end

-- param lightIds
-- param active
function v_setLightsActive(args, board)
  for _, id in ipairs(args.lightIds) do
    world.sendEntityMessage(id, "setActive", args.active)
  end
  
  return true
end

-- param coreIds
-- param teleportPool
function v_moveCoresAroundRandomly(args, board)
  local teleportPool = args.teleportPool
  shuffle(teleportPool)
  for i, coreId in ipairs(args.coreIds) do
    local teleportPos = teleportPool[i]
    world.sendEntityMessage(coreId, "notify", {
      type = "teleport",
      targetPosition = teleportPos
    })
  end
  
  return true
end

-- param coreIds
-- param loops
-- param waitTime
-- param centerOffset
-- param target
function v_coreAttack6(args, board)
  local center = vec2.add(mcontroller.position(), args.centerOffset)
  for i = 1, args.loops do
    local nCoreIds = #args.coreIds
    local endAngle = util.randomInRange({0, 2 * math.pi})
    for j, coreId in ipairs(args.coreIds) do
      if world.entityExists(coreId) then
        notification = {
          type = "attack6",
          endAngle = endAngle,
          angleOffset = util.wrapAngle((j - 1) * 2 * math.pi / nCoreIds),
          center = center,
          target = args.target,
          sourceId = entity.id(),
          teleTime = args.teleTime
        }
        world.sendEntityMessage(coreId, "notify", notification)
      else
        nCoreIds = nCoreIds - 1
      end
    end
    _v_awaitNotification("finishedcore", nCoreIds)
    util.run(args.waitTime, function() end)
  end

  for i, coreId in ipairs(args.coreIds) do
    if world.entityExists(coreId) then
      notification = {
        type = "resetPos",
        sourceId = entity.id()
      }
      world.sendEntityMessage(coreId, "notify", notification)
    end
  end

  return true
end

-- param coreIds
-- param monsterType
-- output shieldCoreIds
function v_spawnShieldCores(args, board)
  --local shieldCoreIds = {}
  for _, coreId in ipairs(args.coreIds) do
    --local shieldCoreId = world.spawnMonster(args.monsterType, world.entityPosition(coreId), {level = monster.level(), target = coreId})
    --table.insert(shieldCoreIds, shieldCoreId)
    world.sendEntityMessage(coreId, "notify", {type = "activateShieldCore"})
  end
  
  --return true, {shieldCoreIds = shieldCoreIds}
  return true, {shieldCoreIds = {}}
end

function _v_awaitNotification(type_, count)
  count = count or 1
  local notifications = {}
  while count > 0 do
    local i = 1
    while i <= #self.notifications do
      local notification = self.notifications[i]
      if notification.type == type_ then
        --sb.logInfo("self.notifications = %s, i = %s", self.notifications, i)
        table.remove(self.notifications, i)
        table.insert(notifications, notification)

        count = count - 1
      else
        i = i + 1
      end
    end
    coroutine.yield()
  end

  return notifications
end

function _getCappedTargetPos(target, hPosBounds, vPosBounds)
  local targetPos = world.entityPosition(target)
  return {math.max(vPosBounds[1], math.min(targetPos[1], vPosBounds[2])), math.max(hPosBounds[1], math.min(targetPos[2], hPosBounds[2]))}
end