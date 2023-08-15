require "/scripts/util.lua"
require "/scripts/vec2.lua"

-- Makes the miniboss face toward the aim vector and aim both arms at it.
-- param aimVector
-- param frontArmRotationCenter
-- param backArmRotationCenter
function v_aimAtVector(args, board)
  -- Check for bad input
  if not args.aimVector then
    sb.logWarn("v_aimAtVector: args.aimVector not defined")
    return false
  end
  
  if not args.frontArmRotationCenter then
    sb.logWarn("v_aimAtVector: args.frontArmRotationCenter not defined")
    return false
  end
  
  if not args.backArmRotationCenter then
    sb.logWarn("v_aimAtVector: args.backArmRotationCenter not defined")
    return false
  end

  -- Get direction
  local direction = util.toDirection(args.aimVector[1])
  -- This aim angle is to compensate for the flipped sprite
  local aimAngle = vec2.angle(vec2.mul(args.aimVector, {direction, 1}))

  -- Set facing direction
  mcontroller.controlFace(direction)
  
  -- Rotate arms
  animator.resetTransformationGroup("frontarm")
  animator.resetTransformationGroup("backarm")

  animator.rotateTransformationGroup("frontarm", aimAngle, args.frontArmRotationCenter)
  animator.rotateTransformationGroup("backarm", aimAngle, args.backArmRotationCenter)
  
  local muzzleOffset = animator.partPoint("frontarm", "muzzleOffset")
  
  return true, {projectileOffset = muzzleOffset}
end

-- Makes the miniboss smoothly transition from its starting angle to the 0 angle.
-- param startAngle
-- param resetTime
function v_smoothReset(args, board)
  -- Check for bad input
  if not args.startAngle then
    sb.logWarn("v_smoothReset: args.startAngle not defined")
    return false
  end
  
  if not args.resetTime then
    sb.logWarn("v_smoothReset: args.resetTime not defined")
    return false
  end
  
  local timer = 0
  util.run(args.resetTime, function(dt)
    local progress = timer / args.resetTime

    -- Apply ease-in-out-sine interpolation to progress ratio (second argument is delta)
    local angle = util.easeInOutSin(progress, args.startAngle, -args.startAngle)
    
    animator.resetTransformationGroup("body")
    animator.rotateTransformationGroup("body", angle)
    
    timer = timer + dt
  end)
  
  animator.resetTransformationGroup("body")  -- So that the miniboss isn't *slightly* tilted at the end.
  
  return true
end

--[[ 
  A variant of battleMusic that is designed specifically for v-cityminibossmusic (see 
  /stagehands/v-cityminibossmusic/v-cityminibossmusic.lua)
]]
-- param state
function v_setBattleMusicState(args, board)
  if not args.state then
    sb.logWarn("v_setBattleMusicState: args.state not defined")
    return false
  end

  if self.musicState ~= args.state then
    local musicStagehands = config.getParameter("musicStagehands")
    if not musicStagehands then
      sb.logInfo("The monster's musicStagehands parameter (a uniqueId) must be configured for v_setBattleMusicState")
      return false
    end
    for _, stagehand in pairs(musicStagehands) do
      local entityId = world.loadUniqueEntity(stagehand)

      if entityId and world.entityExists(entityId) then
        world.callScriptedEntity(entityId, "setMusicState", args.state)
        self.musicState = args.state
      end
    end
  end

  return true
end