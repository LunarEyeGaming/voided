require "/scripts/util.lua"
require "/scripts/poly.lua"
require "/scripts/rect.lua"

local swimSpeed
local swimForce

local changeDirectionTestDistance

local currentDirection
local state

function init()
  monster.setDamageOnTouch(true)

  swimSpeed = config.getParameter("swimSpeed")
  swimForce = config.getParameter("swimForce")
  changeDirectionTestDistance = config.getParameter("changeDirectionTestDistance")

  monster.setDeathParticleBurst("deathPoof")

  if animator.hasSound("deathPuff") then
    monster.setDeathSound("deathPuff")
  end

  animator.setGlobalTag("inflateStatus", "normal")

  message.setHandler("despawn", despawn)

  currentDirection = util.randomDirection()

  state = FSM:new()
  state:set(states.swim)
end

function update(dt)
  local isStunned = status.resourcePositive("stunned")

  -- Update stunned state and damage on touch.
  animator.setAnimationState("damage", isStunned and "stunned" or "none")

  if not isStunned then
    state:update()
  end

end

states = {}

function states.swim()
  -- local direction = 1

  -- -- Reset animation state
  -- animator.setAnimationState("movement", "swimFast")

  -- -- Swim back and forth
  -- while true do
  --   -- If the monster is out of liquid...
  --   if not mcontroller.liquidMovement() then
  --     state:set(states.outOfLiquid)
  --   end

  --   -- If colliding with a wall...
  --   if util.blockSensorTest("blockedSensors", direction) then
  --     direction = -direction
  --   end

  --   --mcontroller.controlApproachVelocity(vec2.mul({direction, 0}, swimSpeed), swimForce)
  --   -- Swim
  --   mcontroller.controlFly({direction, 0})
  --   mcontroller.controlFace(direction)

  --   coroutine.yield()
  -- end
  local changeDirectionTime = 0.15
  local boostDelay = 1.5
  local boostDuration = 0.25
  local postBoostDelay = 1.0
  local waitTime = 2.0
  local boostSpeed = nil

  while true do
    local thread1 = coroutine.create(function()
      local testRect = getTestRect(currentDirection)
      if world.rectCollision(testRect) then
        currentDirection = -currentDirection
        util.wait(changeDirectionTime)
      end

      animator.setAnimationState("movement", "boostwindup")

      util.wait(boostDelay, function()
        mcontroller.controlFace(currentDirection)
      end)

      animator.setAnimationState("movement", "boost")

      util.wait(boostDuration, function()
        if boostSpeed then
          mcontroller.controlParameters({flySpeed = boostSpeed})
        end
        mcontroller.controlFly({currentDirection, 0})
        mcontroller.controlFace(currentDirection)
      end)

      util.wait(postBoostDelay)

      animator.setAnimationState("movement", "boostwinddown")

      util.wait(waitTime)
    end)
    local thread2 = coroutine.create(function()
      while true do
        if not mcontroller.liquidMovement() then
          state:set(states.outOfLiquid)
          return
        end

        coroutine.yield()
      end
    end)

    while util.parallel(thread1, thread2) do
      coroutine.yield()
    end
    coroutine.yield()
  end
end

function states.outOfLiquid()
  animator.setAnimationState("movement", "flopping")

  -- Flop around.
  while not mcontroller.liquidMovement() do
    -- if mcontroller.onGround() then
    --   local jumpDirection = util.randomDirection()
    --   mcontroller.controlMove(jumpDirection)
    --   mcontroller.controlJump()
    -- end

    coroutine.yield()
  end

  state:set(states.swim)
end

function getTestRect(direction)
  local ownRect = mcontroller.boundBox()
  if direction > 0 then
    ownRect[3] = ownRect[3] + changeDirectionTestDistance
  else
    ownRect[1] = ownRect[1] - changeDirectionTestDistance
  end

  return rect.translate(ownRect, mcontroller.position())
end

function despawn()
  monster.setDropPool(nil)
  monster.setDeathParticleBurst(nil)
  monster.setDeathSound(nil)
  status.addEphemeralEffect("monsterdespawn")
end