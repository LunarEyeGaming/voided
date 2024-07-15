require "/scripts/util.lua"
require "/scripts/poly.lua"
require "/scripts/rect.lua"
require "/scripts/status.lua"

--[[
  Behavior:
  * Swim back and forth.
  * If at any point it takes damage and it has not already inflated:
    * Gracefully come to a halt
    * Play the inflate animation and sound
    * Turn on contact damage
    * Continue swimming back and forth
  * If at any point it exits water:
    * If it is not inflated:
      * Set state to flop
      * Play flopping animation
      * Flop around
      * In this state, it is not able to inflate.
    * Else:
      * Stand still
]]

local notInflated  -- True if the monster has not begun inflating
local isInflated  -- True if the monster has finished inflating (not necessarily true if notInflated is false)


local swimSpeed
local swimForce
local preInflateStopTime
local preInflateStopForce

local inflateTime
local inflateSize

local postInflateTime

local inflatedCollisionPoly

local tookDamage
local listener
local state

function init()
  notInflated = true
  isInflated = false
  
  swimSpeed = config.getParameter("swimSpeed")
  swimForce = config.getParameter("swimForce")
  preInflateStopTime = config.getParameter("preInflateStopTime")
  preInflateStopForce = config.getParameter("preInflateStopForce")
  
  inflateTime = config.getParameter("inflateTime", 0.2)
  inflateSize = config.getParameter("inflateSize", 4)
  
  postInflateTime = config.getParameter("postInflateTime")
  
  inflationCollisionPoly = config.getParameter("inflationCollisionPoly")
  inflatedCollisionPoly = poly.scale(inflationCollisionPoly, inflateSize)

  monster.setDeathParticleBurst("deathPoof")
  
  animator.setGlobalTag("inflateStatus", "normal")

  if animator.hasSound("deathPuff") then
    monster.setDeathSound("deathPuff")
  end
  
  message.setHandler("despawn", despawn)
  
  listener = damageListener("damageTaken", function()
    tookDamage = true
  end)
  
  tookDamage = false
  
  state = FSM:new()
  state:set(states.swim)
end

function update(dt)
  listener:update()
  state:update()
  
  tookDamage = false
  
  if isInflated then
    mcontroller.controlParameters({collisionPoly = inflatedCollisionPoly})
  end
end

states = {}

function states.swim()
  local direction = 1
  
  -- Reset animation state
  animator.setAnimationState("body", isInflated and "inflated" or "normal")
  
  -- Swim back and forth
  while true do
    -- If the monster is out of liquid...
    if not mcontroller.liquidMovement() then
      state:set(states.outOfLiquid)
    end

    -- If the monster took damage and is not inflated...
    if notInflated and tookDamage then
      state:set(states.inflate)
    end
    
    -- If colliding with a wall...
    if isWallColliding({direction, 0}) then
      direction = -direction
    end
    
    --mcontroller.controlApproachVelocity(vec2.mul({direction, 0}, swimSpeed), swimForce)
    -- Swim
    mcontroller.controlFly({direction, 0})
    mcontroller.controlFace(direction)

    coroutine.yield()
  end
end

function states.inflate()
  notInflated = false

  animator.setAnimationState("body", "preinflate")
  
  -- Halt
  util.wait(preInflateStopTime, function()
    mcontroller.controlApproachVelocity({0, 0}, preInflateStopForce)
  end)
  
  -- Begin inflation
  animator.setGlobalTag("inflateStatus", "inflated")
  animator.setAnimationState("body", "inflate")
  animator.playSound("inflate")
  
  local timer = 0

  -- Grow collision poly
  util.wait(inflateTime, function(dt)
    local size = util.lerp(timer / inflateTime, 1, inflateSize)
    mcontroller.controlParameters({collisionPoly = poly.scale(inflationCollisionPoly, size)})
    timer = timer + dt
  end)
  
  isInflated = true
  
  monster.setDamageOnTouch(true)
  
  util.wait(postInflateTime)
  
  state:set(states.swim)
end

function states.outOfLiquid()
  animator.setAnimationState("body", "flop")

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

function isWallColliding(dirVector)
  local bounds = rect.translate(mcontroller.boundBox(), mcontroller.position())

  if dirVector == nil then
    bounds = rect.pad(bounds, 0.25)
  elseif dirVector[1] > 0 then
    bounds[1] = bounds[3]
    bounds[3] = bounds[3] + 0.25
  elseif dirVector[1] < 0 then
    bounds[3] = bounds[1]
    bounds[1] = bounds[1] - 0.25
  elseif dirVector[2] > 0 then
    bounds[2] = bounds[4]
    bounds[4] = bounds[4] + 0.25
  else
    bounds[4] = bounds[2]
    bounds[2] = bounds[2] - 0.25
  end
  util.debugRect(bounds, "yellow")

  return world.rectTileCollision(bounds, {"Null","Block","Dynamic"})
end

function despawn()
  monster.setDropPool(nil)
  monster.setDeathParticleBurst(nil)
  monster.setDeathSound(nil)
  status.addEphemeralEffect("monsterdespawn")
end