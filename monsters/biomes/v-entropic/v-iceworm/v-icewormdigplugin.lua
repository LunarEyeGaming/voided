require "/scripts/vec2.lua"

local oldInit = init or function() end
local oldUpdate = update or function() end
local oldUninit = uninit or function() end

local digMode
local digCheck

local wasDigging
local prevSpeed

local prevPosition
local prevPosition2
local prevPosition3

function init()
  oldInit()

  -- sb.logInfo("Ice worm %s spawned", entity.id())

  digMode = config.getParameter("digMode") or "all"

  if digMode == "ground" then
    digCheck = function()
      return world.pointCollision(mcontroller.position())
    end
  elseif digMode == "groundAndLiquid" then
    digCheck = function()
      return world.pointCollision(mcontroller.position()) or world.liquidAt(mcontroller.position())
    end
  elseif digMode == "all" then
    digCheck = function()
      return true
    end
  end

  prevPosition = mcontroller.position()
  prevPosition2 = prevPosition
  prevPosition3 = prevPosition2

  wasDigging = false
  prevSpeed = 0
end

function update(dt)
  oldUpdate(dt)

  local speed = deriveSpeed(dt)
  local isDigging = digCheck()

  if speed > 0 and prevSpeed > 0 then
    if isDigging and not wasDigging then
      animator.playSound("digBegin")
      animator.burstParticleEmitter("digBegin")
      animator.playSound("digLoop", -1)
      animator.setParticleEmitterActive("dig", true)
    end

    if not isDigging and wasDigging then
      animator.playSound("digEnd")
      animator.burstParticleEmitter("digEnd")
      animator.stopAllSounds("digLoop")
      animator.setParticleEmitterActive("dig", false)
    end
  end

  if isDigging and wasDigging then
    if speed > 0 and prevSpeed <= 0 then
      animator.playSound("digLoop", -1)
      animator.setParticleEmitterActive("dig", true)
    end

    if speed <= 0 and prevSpeed > 0 then
      animator.stopAllSounds("digLoop")
      animator.setParticleEmitterActive("dig", false)
    end
  end

  wasDigging = isDigging
  prevSpeed = speed

  world.debugText("%s", speed, mcontroller.position(), speed == 0 and "red" or "green")

  -- Zoomed out view
  local playerId = world.players()[1]
  if playerId and world.entityExists(playerId) then
    local playerPos = world.entityPosition(playerId)

    local zoomOut = function(anchor, pos, factor)
      local posRelative = world.distance(pos, anchor)
      return vec2.add(vec2.mul(posRelative, 1 / factor), anchor)
    end

    local zoomedOutPos = zoomOut(playerPos, mcontroller.position(), 16)
    world.debugText("O", zoomedOutPos, "white")
  end
end

function deriveSpeed(dt)
  local speed = vec2.mag(world.distance(mcontroller.position(), prevPosition3)) / (3 * dt)

  prevPosition3 = prevPosition2
  prevPosition2 = prevPosition
  prevPosition = mcontroller.position()

  return speed
end

-- function uninit()
--   oldUninit()
--   sb.logInfo("Ice worm %s died", entity.id())
-- end