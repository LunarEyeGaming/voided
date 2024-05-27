require "/scripts/vec2.lua"

local liquidId
local liquidQuantity
local liquidOffset
local liquidSpawnInterval
local maxPlayerDistance

local stopControlForce

local stoppedObjectType
local stoppedObjectOffset

local liquidSpawnTimer

local shouldStop
local hasStopped

function init()
  liquidId = config.getParameter("liquidId", 1)
  liquidQuantity = config.getParameter("liquidQuantity", 1)
  liquidOffset = config.getParameter("liquidOffset", {0, 0})
  liquidSpawnInterval = config.getParameter("liquidSpawnInterval", 0.04)
  maxPlayerDistance = config.getParameter("maxPlayerDistance")
  
  stopControlForce = config.getParameter("stopControlForce", 15)
  
  stoppedObjectType = config.getParameter("stoppedObjectType", "v-liquiddumpingcratestopped")
  stoppedObjectOffset = config.getParameter("stoppedObjectOffset", {0, 0})

  liquidSpawnTimer = liquidSpawnInterval
  
  shouldStop = false
  hasStopped = false
  
  message.setHandler("v-liquiddumpingcrate-stop", function()
    shouldStop = true
  end)
end

function update(dt)
  liquidSpawnTimer = liquidSpawnTimer - dt
  
  local liquidPos = vec2.add(mcontroller.position(), liquidOffset)

  -- If it is time to spawn the liquid and there is at least one player nearby...
  if liquidSpawnTimer <= 0 and playerNearby() then
    world.spawnLiquid(liquidPos, liquidId, liquidQuantity)
    liquidSpawnTimer = liquidSpawnInterval
  end
  
  -- If the tank should stop...
  if shouldStop then
    -- Continuously decelerate.
    mcontroller.approachVelocity({0, 0}, stopControlForce)
    
    -- If the tank has stopped (and the hasStopped flag has not been set, to prevent this code from activating multiple times)...
    if vec2.mag(mcontroller.velocity()) == 0 and not hasStopped then
      -- Place the object variant (forcibly).
      placeObject()
      hasStopped = true
      
      -- Die
      projectile.die()
    end
  end
end

function playerNearby()
  for _, playerId in ipairs(world.players()) do
    -- If the player exists and they are close enough to the projectile's position...
    if world.entityExists(playerId) and world.magnitude(mcontroller.position(), world.nearestTo(mcontroller.position(), world.entityPosition(playerId))) <= maxPlayerDistance then
      return true
    end
  end
  
  return false
end

function placeObject()
  local placementPosition = vec2.add(mcontroller.position(), stoppedObjectOffset)
  local isTileProtected = world.isTileProtected(placementPosition)
  local dungeonId = world.dungeonId(placementPosition)
  
  -- Temporarily disable tile protection so that it can place the object.
  if isTileProtected then
    world.setTileProtection(dungeonId, false)
  end
  
  -- Place the object
  world.placeObject(stoppedObjectType, placementPosition, 1)
  
  -- Turn tile protection back on.
  if isTileProtected then
    world.setTileProtection(dungeonId, true)
  end
end

function destroy()
  -- If the projectile has not died because it stopped...
  if not hasStopped then
    -- Process the actions, using a proxy projectile because of the function's limitations
    projectile.processAction({
      action = "projectile",
      type = "v-proxyprojectile",
      config = {
        actionOnReap = config.getParameter("teleportActions", jarray())
      }
    })
  end
end