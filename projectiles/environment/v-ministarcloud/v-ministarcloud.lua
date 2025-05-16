require "/scripts/v-ministarutil.lua"
require "/scripts/rect.lua"

local dieInProtectedAreas
local diedInInit
local liquidId
local moveSpeed
local moveForce
local heightMapSetRange
local minDepth

local moveDirection

function init()
  dieInProtectedAreas = config.getParameter("dieInProtectedAreas")
  liquidId = config.getParameter("liquidId")
  moveSpeed = config.getParameter("speed")
  moveForce = config.getParameter("moveForce")
  heightMapSetRange = config.getParameter("heightMapSetRange")
  minDepth = world.oceanLevel(mcontroller.position()  --[[@as Vec2I]])

  moveDirection = config.getParameter("moveDirection")
  if not moveDirection then
    if math.random() <= 0.5 then
      moveDirection = 1
    else
      moveDirection = -1
    end
  end

  if dieInProtectedAreas and world.isTileProtected(mcontroller.position()) then
    projectile.die()
    diedInInit = true
    return
  end

  mcontroller.setRotation(0)
end

function update(dt)
  if dieInProtectedAreas and world.isTileProtected(mcontroller.position()) then
    projectile.die()
    return
  end
  local liquid = world.liquidAt(mcontroller.position() --[[@as Vec2I]])

  if liquid and liquid[1] == liquidId then
    mcontroller.approachVelocity({0, moveSpeed}, moveForce)
  else
    local boundBox = rect.translate(mcontroller.collisionBoundBox(), {0.25 * moveDirection, 0})
    if world.rectCollision(boundBox) then
      moveDirection = -moveDirection
    end
    mcontroller.approachVelocity({moveSpeed * moveDirection, 0}, moveForce)
  end

  local ownPos = mcontroller.position()
  local ownPosI = {
    math.floor(ownPos[1]),
    math.floor(ownPos[2])
  }

  if ownPosI[2] > minDepth then
    local startX = ownPosI[1] + heightMapSetRange[1]
    local endX = ownPosI[1] + heightMapSetRange[2]

    local heightMap = vMinistar.HeightMap:new(startX)

    for x = startX, endX do
      heightMap:set(math.floor(x), ownPosI[2])
    end

    registerEntityCollision(heightMap)
  end
end

function destroy()
  if not diedInInit then
    local disappearProjectile = config.getParameter("disappearProjectile")
    if disappearProjectile then
      world.spawnProjectile(disappearProjectile, mcontroller.position(), projectile.sourceEntity(), {moveDirection, 0}, false, {
        moveDirection = moveDirection
      })
    end
  end
end

function uninit()
  deregisterEntityCollision()
end

function registerEntityCollision(heightMap)
  for _, entityId in ipairs(world.entityQuery(mcontroller.position(), 250, {includedTypes = {"player"}})) do
    world.sendEntityMessage(entityId, "v-ministarheat-setEntityCollision", entity.id(), heightMap)
  end
end

function deregisterEntityCollision()
  for _, entityId in ipairs(world.entityQuery(mcontroller.position(), 250, {includedTypes = {"player"}})) do
    world.sendEntityMessage(entityId, "v-ministarheat-setEntityCollision", entity.id(), nil)
  end
end