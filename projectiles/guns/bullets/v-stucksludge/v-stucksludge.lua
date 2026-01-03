require "/scripts/projectiles/v-mergergeneric.lua"
require "/scripts/vec2.lua"
require "/scripts/poly.lua"

local oldInit = init or function() end
local oldUpdate = update or function() end

local clingSpeed
local clingControlForce
local actionOnMerge
local actionOnNonMerge
local mergeHandlerType
local selfMergeHandlerType
local ownType  ---@type string
local otherType  ---@type string

local merger

function init()
  -- sb.logInfo("spawned: %s", entity.id())

  actionOnMerge = config.getParameter("actionOnMerge")
  actionOnNonMerge = config.getParameter("actionOnNonMerge")
  mergeHandlerType = config.getParameter("mergeHandlerType")
  selfMergeHandlerType = config.getParameter("selfMergeHandlerType")
  ownType = config.getParameter("projectileName")

  vMergeHandler.set(mergeHandlerType, false, function(otherEntity_, senderSourceEntity)
    -- sb.logInfo("handled other merge with entity %s", otherEntity_)
    -- Ensure that the sender has the same source entity as the current projectile.
    return senderSourceEntity == projectile.sourceEntity()
  end)

  vMergeHandler.set(selfMergeHandlerType, true, function(otherEntity_, senderSourceEntity, otherType_)
    otherType = otherType_
    otherEntity = otherEntity_
    -- sb.logInfo("handled self merge with entity %s", otherEntity_)
    -- Ensure that the sender has the same source entity as the current projectile.
    if senderSourceEntity == projectile.sourceEntity() then
      return true, ownType
    end

    return false
  end)

  clingSpeed = config.getParameter("clingSpeed", 50)
  clingControlForce = config.getParameter("clingControlForce", 1000)

  merger = VMerger:new(selfMergeHandlerType, config.getParameter("mergeRadius"), false, false)
end

function update(dt)
  local results = merger:process(projectile.sourceEntity(), ownType)
  if #results > 0 then
    -- sb.logInfo("%s", results)
    projectile.die()
  end

  updateStick()
end

function updateStick()
  -- Adjust rotation to face into the ground.
  local groundDirection = findGroundDirection(0.75)
  local headingAngle
  if groundDirection then
    world.debugLine(mcontroller.position(), vec2.add(groundDirection, mcontroller.position()), "green")
    headingAngle = vec2.angle(groundDirection)
    mcontroller.approachVelocity(vec2.withAngle(headingAngle, clingSpeed), clingControlForce)
    mcontroller.applyParameters({gravityEnabled = false})
  else
    headingAngle = vec2.angle(mcontroller.velocity())
    mcontroller.applyParameters({gravityEnabled = true})
  end
  mcontroller.setRotation(headingAngle)
end

function findGroundDirection(testDistance)
  testDistance = testDistance or 0.25

  local pointCount = 8

  -- Counter-clockwise
  local angle1
  for i = 0, pointCount - 1 do
    local angle = (i * 2 * math.pi / pointCount) - math.pi / 2
    local testPos = vec2.add(mcontroller.position(), vec2.withAngle(angle, testDistance))
    if world.polyCollision(poly.translate(mcontroller.collisionPoly(), testPos)) then
      angle1 = angle
      break
    end
  end

  -- Clockwise
  local angle2
  for i = 0, pointCount - 1 do
    local angle = -(i * 2 * math.pi / pointCount) - math.pi / 2
    local testPos = vec2.add(mcontroller.position(), vec2.withAngle(angle, testDistance))
    if world.polyCollision(poly.translate(mcontroller.collisionPoly(), testPos)) then
      angle2 = angle
      break
    end
  end

  if not (angle1 and angle2) then
    return nil
  end

  -- Since there are two possibilities, test the two angles that bisect angle1 and angle2 and see which one leads to a
  -- collision.
  local angle = (angle1 + angle2) / 2
  local testPos = vec2.add(mcontroller.position(), vec2.withAngle(angle, testDistance))
  if world.polyCollision(poly.translate(mcontroller.collisionPoly(), testPos)) then
    return vec2.withAngle(angle, 1.0)
  end

  angle = angle + math.pi
  local testPos = vec2.add(mcontroller.position(), vec2.withAngle(angle, testDistance))
  if world.polyCollision(poly.translate(mcontroller.collisionPoly(), testPos)) then
    return vec2.withAngle(angle, 1.0)
  end
end

function destroy()
  -- sb.logInfo("died: %s", entity.id())
  if vMergeHandler.isMerged() then
    if actionOnMerge then
      projectile.processAction(actionOnMerge)
    else
      local otherTypeNumber = otherType and tonumber(otherType:sub(otherType:len()))
      local ownTypeNumber = tonumber(ownType:sub(ownType:len()))

      -- sb.logInfo("own: (%s, %s), other: (%s, %s)", entity.id(), ownType, otherEntity, otherType)

      if otherTypeNumber then  -- v-sludge
        newTypeNumber = otherTypeNumber + ownTypeNumber
      else  -- v-stucksludge<otherTypeNumber>
        newTypeNumber = ownTypeNumber + 1
      end

      if newTypeNumber > 4 then
        local actions = {
          {
            action = "config",
            file = "/projectiles/explosions/regularexplosion2/v-lua-poisonexplosionknockback.config"
          }
        }
        for i = 0, newTypeNumber - 1 do
          local angle = util.lerp(i / (newTypeNumber - 1), -80, 80) + 180
          local action = {
            action = "projectile",
            type = "v-sludge",
            inheritDamageFactor = 1.0,
            angleAdjust = angle,
            fuzzAngle = 10,
            config = {
              mergeDelay = 0.2
            }
          }
          table.insert(actions, action)
        end
        projectile.processAction({
          action = "actions",
          list = actions
        })
      else
        -- sb.logInfo("Attempting to spawn projectile with type %s", ownType:sub(1, ownType:len() - 1) .. newTypeNumber)
        projectile.processAction({
          action = "projectile",
          type = ownType:sub(1, ownType:len() - 1) .. newTypeNumber,
          inheritDamageFactor = 1,
          inheritSpeedFactor = 1
        })
      end
    end
  elseif not merger:isMerged() then
    projectile.processAction(actionOnNonMerge)
  end
end