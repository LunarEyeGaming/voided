require "/scripts/vec2.lua"
require "/scripts/util.lua"

function init()
  self.recoil = 0
  self.recoilRate = 0

  self.fireOffset = config.getParameter("fireOffset")
  updateAim()

  self.active = false
  storage.fireTimer = storage.fireTimer or 0
end

function update(dt, fireMode, shiftHeld)
  updateAim()

  storage.fireTimer = math.max(storage.fireTimer - dt, 0)

  if self.active then
    self.recoilRate = 0
  else
    self.recoilRate = math.max(1, self.recoilRate + (10 * dt))
  end
  self.recoil = math.max(self.recoil - dt * self.recoilRate, 0)

  if self.active and not storage.firing and storage.fireTimer <= 0 then
    self.recoil = math.pi/2 - self.aimAngle
    activeItem.setArmAngle(math.pi/2)
    if animator.animationState("firing") == "off" then
      animator.setAnimationState("firing", "fire")
    end
    storage.fireTimer = config.getParameter("fireTime", 1.0)
    storage.firing = true

  end

  self.active = false

  if storage.firing and animator.animationState("firing") == "off" then
    if player then
      local tech = config.getParameter("unlockedTech")
      local equipTech = config.getParameter("forceEquipTech")

      local techIsUnlocked = contains(player.enabledTechs(), tech)

      if not techIsUnlocked or equipTech then
        if not techIsUnlocked then
          player.makeTechAvailable(tech)
          player.enableTech(tech)
        end

        if equipTech then
          player.equipTech(tech)
        end

        -- As this uses currencies for notifications, programmers adding a new tech chip should change the text
        -- according to whether or not forceEquipTech is true.
        player.giveItem(config.getParameter("unlockedTechNotifierName"))

        item.consume(1)
      else
        player.giveItem("v-techalreadyunlockednotifier")
      end
    else
      item.consume(1)
    end
    storage.firing = false
    return
  end
end

function activate(fireMode, shiftHeld)
  if not storage.firing then
    self.active = true
  end
end

function updateAim()
  self.aimAngle, self.aimDirection = activeItem.aimAngleAndDirection(self.fireOffset[2], activeItem.ownerAimPosition())
  self.aimAngle = self.aimAngle + self.recoil
  activeItem.setArmAngle(self.aimAngle)
  activeItem.setFacingDirection(self.aimDirection)
end

function firePosition()
  return vec2.add(mcontroller.position(), activeItem.handPosition(self.fireOffset))
end

function aimVector()
  local aimVector = vec2.rotate({1, 0}, self.aimAngle + sb.nrand(config.getParameter("inaccuracy", 0), 0))
  aimVector[1] = aimVector[1] * self.aimDirection
  return aimVector
end

function holdingItem()
  return true
end

function recoil()
  return false
end

function outsideOfHand()
  return false
end
