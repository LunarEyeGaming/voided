require "/tech/distortionsphere/spikesphere.lua"
require "/scripts/vec2.lua"

local oldInit = init or function() end
local oldUpdate = update or function() end
local oldActivate = activate or function() end
local oldDeactivate = deactivate or function() end

local hookProjectileType
local launchSpeed
local launchDistance
local reelSpeed
local reelForce
local finishTolerance
local hookLaunchCost

local state
local hookId

local prevDown

local BOUND_BOX_PADDING = 0.25

function init()
  oldInit()

  hookProjectileType = config.getParameter("hookProjectileType")
  launchSpeed = config.getParameter("launchSpeed")
  launchDistance = config.getParameter("launchDistance")
  reelSpeed = config.getParameter("reelSpeed")
  reelForce = config.getParameter("reelForce")
  finishTolerance = config.getParameter("finishTolerance")
  hookLaunchCost = config.getParameter("hookLaunchCost")

  state = nil
end

function update(args)
  oldUpdate(args)

  local ownPos = mcontroller.position()

  if self.active then
    if not state
    and not args.moves["run"]
    and prevDown ~= args.moves["run"]
    and status.overConsumeResource("energy", hookLaunchCost) then
      state = "launch"
    end

    prevDown = args.moves["run"]

    if state == "launch" then
      local direction = world.distance(tech.aimPosition(), ownPos)
      hookId = world.spawnProjectile(hookProjectileType, ownPos, entity.id(), direction, false, {
        speed = launchSpeed,
        launchDistance = launchDistance
      })
      state = "grapple"
    elseif hookId and world.entityExists(hookId) then
      local hookPos = world.entityPosition(hookId)
      local distance = world.distance(hookPos, ownPos)

      if state == "grapple" then
        local anchored = world.callScriptedEntity(hookId, "anchored")

        if anchored then
          state = "reel"
        end
      elseif state == "reel" then
        -- Reel toward hook
        local direction = vec2.norm(distance)
        mcontroller.controlApproachVelocity(vec2.mul(direction, reelSpeed), reelForce)

        -- Checks.
        local inLineOfSight = not world.lineCollision(hookPos, ownPos)
        local paddedBoundBox = rect.pad(mcontroller.boundBox(), BOUND_BOX_PADDING)

        -- If the player has reached the destination or has come into contact with an obstruction...
        if (inLineOfSight and vec2.mag(distance) < finishTolerance)
        or (not inLineOfSight and world.rectCollision(rect.translate(paddedBoundBox, ownPos))) then
          world.callScriptedEntity(hookId, "kill")
          hookId = nil
          state = nil  -- Finish grapple.
        end
      end

      animator.setAnimationState("beam", "on")
      animator.setAnimationState("hookbase", "on")
      animator.resetTransformationGroup("beam")
      animator.scaleTransformationGroup("beam", {vec2.mag(distance), 1})
      animator.resetTransformationGroup("hookbase")
      animator.rotateTransformationGroup("hookbase", vec2.angle(distance))
    else
      animator.setAnimationState("beam", "off")
      animator.setAnimationState("hookbase", "off")
      animator.resetTransformationGroup("hookbase")

      state = nil
    end
  end
end

function activate()
  oldActivate()

  state = "launch"
end

function deactivate()
  oldDeactivate()

  animator.setAnimationState("hookbase", "invisible")

  if hookId and world.entityExists(hookId) then
    animator.setAnimationState("beam", "off")

    world.callScriptedEntity(hookId, "kill")
    hookId = nil
  end
end