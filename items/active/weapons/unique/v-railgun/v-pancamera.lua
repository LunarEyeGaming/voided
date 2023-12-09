require "/scripts/util.lua"
require "/scripts/vec2.lua"
require "/scripts/interp.lua"

v_PanCamera = WeaponAbility:new()

function v_PanCamera:init()
  self.isActive = false
end

function v_PanCamera:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)
  
  if self.isActive then
    -- Need the offset from the camera
    local offset = world.distance(activeItem.ownerAimPosition(), world.entityPosition(self.cameraId))
    
    world.sendEntityMessage(self.cameraId, "v-approachCameraPos", vec2.add(mcontroller.position(), offset))
  end

  if self:pressedAltFire(self.fireMode) then
    -- Activate
    if not self.isActive then
      self.isActive = true

      self.cameraId = self:spawnCamera()
      
      activeItem.setCameraFocusEntity(self.cameraId)
    else  -- Deactivate
      self:reset()
    end
  end
end

function v_PanCamera:pan()
  self.isActive = true

  self.cameraId = self:spawnCamera()
  
  activeItem.setCameraFocusEntity(self.cameraId)

  while self.fireMode == "alt" do
    -- Need the offset from the camera
    local offset = world.distance(activeItem.ownerAimPosition(), world.entityPosition(self.cameraId))
    
    world.sendEntityMessage(self.cameraId, "v-approachCameraPos", vec2.add(mcontroller.position(), offset))

    coroutine.yield()
  end
end

function v_PanCamera:spawnCamera()
  local projectileId = world.spawnProjectile("v-camerapanner", mcontroller.position())
  
  if not projectileId then
    error("Failed to spawn camera panner projectile")
  end
  
  return projectileId
end

function v_PanCamera:aimVector(angleAdjust, inaccuracy)
  local aimVector = vec2.rotate({1, 0}, self.weapon.aimAngle + angleAdjust + sb.nrand(inaccuracy, 0))
  aimVector[1] = aimVector[1] * mcontroller.facingDirection()
  return aimVector
end

function v_PanCamera:reset()
  self.isActive = false
  world.sendEntityMessage(self.cameraId, "reset", entity.id())
end

function v_PanCamera:pressedAltFire(fireMode)
  local result = self.prevFireMode ~= fireMode and fireMode == "alt"
  
  self.prevFireMode = fireMode
  
  return result
end

function v_PanCamera:uninit()
  self:reset()
end