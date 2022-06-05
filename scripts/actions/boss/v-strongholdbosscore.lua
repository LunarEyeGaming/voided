require "/scripts/util.lua"
require "/scripts/interp.lua"
require "/scripts/vec2.lua"

-- param duration
-- param maxAngularVelocity
function v_rotateLaser(args, board)
  local maxAngularVelocity = util.toRadians(args.maxAngularVelocity) * script.updateDt()
  local timer = 0
  local angle = 0

  util.run(args.duration / 2, function(dt)
    timer = timer + dt
    local angularVelocity = util.lerp(timer / args.duration, 0, maxAngularVelocity)
    angle = angle + angularVelocity
    animator.resetTransformationGroup("laser")
    animator.rotateTransformationGroup("laser", angle)
  end)
  
  util.run(args.duration / 2, function(dt)
    timer = timer + dt
    local angularVelocity = interp.reverse(util.lerp)(timer / args.duration, 0, maxAngularVelocity)
    angle = angle + angularVelocity
    animator.resetTransformationGroup("laser")
    animator.rotateTransformationGroup("laser", angle)
  end)
  
  return true
end

-- param duration
-- param xRadius
-- param yRadius
-- param center
-- param startingAngle
-- param maxAngularVelocity
function v_rotateWithLaser(args, board)
  local maxAngularVelocity = util.toRadians(args.maxAngularVelocity) * script.updateDt()
  local timer = 0
  local angle = util.toRadians(args.startingAngle)

  util.run(args.duration / 2, function(dt)
    timer = timer + dt
    local angularVelocity = util.lerp(timer / args.duration, 0, maxAngularVelocity)
    angle = angle + angularVelocity
    mcontroller.setPosition(vec2.add(args.center, {args.xRadius * math.cos(angle), args.yRadius * math.sin(angle)}))
  end)
  
  util.run(args.duration / 2, function(dt)
    timer = timer + dt
    local angularVelocity = interp.reverse(util.lerp)(timer / args.duration, 0, maxAngularVelocity)
    angle = angle + angularVelocity
    mcontroller.setPosition(vec2.add(args.center, {args.xRadius * math.cos(angle), args.yRadius * math.sin(angle)}))
  end)
  
  return true
end


-- param center
-- param xLength
-- param yLength
-- param angle
-- param angleOffset
-- param rotations
-- param teleTime
function v_teleAngle(args, board, _, dt)
  local finalAngle = args.angle + 2 * math.pi * args.rotations
  local timer = 0
  while timer < args.teleTime do
    timer = timer + dt
    local stepAngle = interp.sin(timer / args.teleTime, 0, finalAngle) + args.angleOffset
    --local offset = polarRect(args.xLength, args.yLength, stepAngle)
    local offset = {args.xLength / 2 * math.cos(stepAngle), args.yLength / 2 * math.sin(stepAngle)}
    mcontroller.setPosition(vec2.add(args.center, offset))
    coroutine.yield(nil, {headingVector = vec2.withAngle(stepAngle)})
  end
  -- util.run(args.teleTime, function(dt)
    -- timer = timer + dt
    -- local stepAngle = interp.sin(timer / args.teleTime, 0, finalAngle)
    -- --local offset = polarRect(args.xLength, args.yLength, stepAngle)
    -- local offset = {15 + 15 * math.cos(stepAngle), 12 + 12 * math.sin(stepAngle)}
    -- sb.logInfo("%s", offset)
    -- mcontroller.setPosition(vec2.add(args.center, offset))
  -- end)
  
  return true
end

-- param position
-- param color
function v_teleportToPosition(args, board)
  animator.setAnimationState("shell", "teleportstart")
  
  local chain = copy(config.getParameter("teleportBeam"))
  chain.sourcePart = "core"
  chain.endPosition = args.position
  
  local projId1 = world.spawnProjectile("v-teleportpoint", args.position, entity.id())
  monster.setAnimationParameter("chains", {chain})
  
  util.run(0.125, function() end)
  
  monster.setAnimationParameter("chains", {})
  animator.setAnimationState("core", "teleportstart" .. args.color)
  
  util.run(0.1, function() end)

  local projId2 = world.spawnProjectile("v-teleportpoint", mcontroller.position(), entity.id())
  mcontroller.setPosition(args.position)
  
  util.run(0.1, function() end)

  world.sendEntityMessage(projId1, "kill")
  animator.setAnimationState("core", "teleportend" .. args.color)
  animator.setAnimationState("shell", "teleportend")
  
  util.run(0.1, function() end)

  world.sendEntityMessage(projId2, "kill")
  
  return true
end

-- param noShieldDuration
-- param monsterType
function v_controlShieldCore(args, board)
  local shieldCoreId = world.spawnMonster(args.monsterType, world.entityPosition(entity.id()), {level = monster.level(), target = entity.id()})
  while true do
    while world.entityExists(shieldCoreId) do
      coroutine.yield()
    end
    util.run(args.noShieldDuration, function() end)
    shieldCoreId = world.spawnMonster(args.monsterType, world.entityPosition(entity.id()), {level = monster.level(), target = entity.id()})
    coroutine.yield()
  end
end