require "/scripts/util.lua"
require "/scripts/poly.lua"
require "/scripts/rect.lua"

--[[
  Behavior:
  * Swim back and forth.
  * If at any point it exits water:
    * If it is not inflated:
      * Set state to flop
      * Play flopping animation
      * Flop around
      * In this state, it is not able to inflate.
    * Else:
      * Stand still
]]

local swimSpeed
local swimForce

local state

function init()
  monster.setDamageOnTouch(true)

  swimSpeed = config.getParameter("swimSpeed")
  swimForce = config.getParameter("swimForce")

  monster.setDeathParticleBurst("deathPoof")

  if animator.hasSound("deathPuff") then
    monster.setDeathSound("deathPuff")
  end

  animator.setGlobalTag("inflateStatus", "normal")

  message.setHandler("despawn", despawn)

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
  local direction = 1

  -- Reset animation state
  animator.setAnimationState("movement", "swimFast")

  -- Swim back and forth
  while true do
    -- If the monster is out of liquid...
    if not mcontroller.liquidMovement() then
      state:set(states.outOfLiquid)
    end

    -- If colliding with a wall...
    if util.blockSensorTest("blockedSensors", direction) then
      direction = -direction
    end

    --mcontroller.controlApproachVelocity(vec2.mul({direction, 0}, swimSpeed), swimForce)
    -- Swim
    mcontroller.controlFly({direction, 0})
    mcontroller.controlFace(direction)

    coroutine.yield()
  end
end

function states.outOfLiquid()
  animator.setAnimationState("movement", "flopping")

  -- Flop around.
  while not mcontroller.liquidMovement() do
    if mcontroller.onGround() then
      local jumpDirection = util.randomDirection()
      mcontroller.controlMove(jumpDirection)
      mcontroller.controlJump()
    end

    coroutine.yield()
  end

  state:set(states.swim)
end

function despawn()
  monster.setDropPool(nil)
  monster.setDeathParticleBurst(nil)
  monster.setDeathSound(nil)
  status.addEphemeralEffect("monsterdespawn")
end