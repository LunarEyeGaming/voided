require "/scripts/v-behavior.lua"
require "/scripts/actions/projectiles.lua"
require "/scripts/util.lua"

-- Spawns a spread of multiple projectiles with a constant angle between each one.
-- param projectileCount - the number of projectiles to spawn
-- param projectileType - the type of projectile to spawn
-- param spreadAngle - the angle between each projectile in degrees
-- param sourceEntity - the source entity to use
-- param position - the base position to spawn the projectile at
-- param offset - the offset to add to the projectile's spawning position
-- param angledOffset - same as offset, but affected by the projectile's angle
-- param aimVector - the direction to aim the spread of projectiles towards
-- param damageRepeatGroup - (optional) the damage repeat group to use for the projectiles. Undefined by default.
-- param uniqueRepeatGroup - (optional) whether or not the repeat group should be unique to the current entity. False by
--                           default
-- param projectileConfig - (optional) the parameters to override for the projectile. None by default.
-- param scalePower - (optional) whether or not to scale the power with the monster's level. False by default
-- param trackSource - (optional) whether or not the projectiles should track the source entity. False by default
function v_spawnProjectileSpread(args, board)
  local rq = vBehavior.requireArgsGen("v_spawnProjectileSpread", args)
  
  if not rq{"projectileCount", "projectileType", "spreadAngle", "sourceEntity", "position", "offset", "angledOffset", 
  "aimVector"} then
    return false
  end
  
  local spreadAngle = util.toRadians(args.spreadAngle)
  local angle = -spreadAngle * (args.projectileCount - 1) / 2

  for i = 1, args.projectileCount do
    local newArgs = {
      position = args.position,
      offset = vec2.add(args.offset, vec2.rotate(args.angledOffset, angle)),
      aimVector = vec2.rotate(args.aimVector, angle),
      projectileType = args.projectileType,
      projectileConfig = args.projectileConfig,
      scalePower = args.scalePower,
      trackSource = args.trackSource,
      sourceEntity = args.sourceEntity,
      damageRepeatGroup = args.damageRepeatGroup,
      uniqueRepeatGroup = args.uniqueRepeatGroup
    }
    spawnProjectile(newArgs, board)
    
    angle = angle + spreadAngle
  end
  
  return true
end

-- Spawns a projectile with the target position set to targetPosition + targetOffset.
-- param projectileType - the type of projectile to spawn
-- param sourceEntity - the source entity to use
-- param position - the base position to spawn the projectile at
-- param offset - the offset to add to the projectile's spawning position
-- param aimVector - the direction to aim the spread of projectiles towards
-- param targetPosition - the base position to which the projectile must go
-- param targetOffset - the offset to add to targetPosition
-- param damageRepeatGroup - (optional) the damage repeat group to use for the projectiles. Undefined by default.
-- param uniqueRepeatGroup - (optional) whether or not the repeat group should be unique to the current entity. False by
--                           default
-- param projectileConfig - (optional) the parameters to override for the projectile. None by default.
-- param scalePower - (optional) whether or not to scale the power with the monster's level. False by default
-- param trackSource - (optional) whether or not the projectiles should track the source entity. False by default
function v_spawnProjectileTargetPos(args, board)
  local rq = vBehavior.requireArgsGen("v_spawnProjectileTargetPos", args)
  
  if not rq{"projectileType", "sourceEntity", "position", "offset", "aimVector", "targetPosition", "targetOffset"} then
    return false
  end
  
  local params = copy(args.projectileConfig)
  
  params.targetPosition = vec2.add(args.targetPosition, args.targetOffset)
  
  local newArgs = {
    position = args.position,
    offset = args.offset,
    aimVector = args.aimVector,
    projectileType = args.projectileType,
    projectileConfig = params,
    scalePower = args.scalePower,
    trackSource = args.trackSource,
    sourceEntity = args.sourceEntity,
    damageRepeatGroup = args.damageRepeatGroup,
    uniqueRepeatGroup = args.uniqueRepeatGroup
  }
  spawnProjectile(newArgs, board)
  
  return true
end