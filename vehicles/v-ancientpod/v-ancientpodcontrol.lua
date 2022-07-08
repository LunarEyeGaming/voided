require "/scripts/vec2.lua"
require "/scripts/util.lua"
require "/vehicles/v-ancientpod/v-ancientpod.lua"

function init()
  initShip()
end

function update(dt)
  local moveDir = {0, 0}
  if hasEnergy() then
    if vehicle.controlHeld("seat", "right") then
      moveDir[1] = moveDir[1] + 1
    end
    if vehicle.controlHeld("seat", "left") then
      moveDir[1] = moveDir[1] - 1
    end
    if vehicle.controlHeld("seat", "up") then
      moveDir[2] = moveDir[2] + 1
    end
    if vehicle.controlHeld("seat", "down") then
      moveDir[2] = moveDir[2] - 1
    end

    if vehicle.controlHeld("seat", "primaryFire") then
      if not isFiring() then
        startFiring()
      end
    elseif isFiring() then
      stopFiring()
    end

    if vehicle.controlHeld("seat", "altFire") then
      if not isFiringAlt() then
        startFiringAlt()
      end
    elseif isFiringAlt() then
      stopFiringAlt()
    end
  else
    if isFiring() then
      stopFiring()
    end
    if isFiringAlt() then
      stopFiringAlt()
    end
  end
  
  local driver = vehicle.entityLoungingIn("seat")
  updateShip(dt, driver, moveDir)
end
