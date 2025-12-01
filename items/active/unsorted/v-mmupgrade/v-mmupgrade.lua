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
    local consumeOnUse = config.getParameter("consumeOnUse", true)
    if player then
      local upgradeName = config.getParameter("upgradeName")
      local upgrade = config.getParameter("upgrade")

      performUpgrade(upgradeName, upgrade, consumeOnUse)
    else
      if consumeOnUse then
        item.consume(1)
      end
    end
    storage.firing = false
    return
  end
end

function performUpgrade(upgradeName, upgrade, consumeOnUse)
  local mm = player.essentialItem("beamaxe")
  if not mm then
    player.giveItem("v-beamaxeslotemptynotifier")
    return
  end

  if contains(mm.parameters.upgrades or {}, upgradeName) then
    player.giveItem("v-beamaxealreadyupgradednotifier")
    return
  end

  if upgrade.sumItemParameters then
    local item = player.essentialItem(upgrade.essentialSlot)
    if item then
      for k, v in pairs(upgrade.sumItemParameters) do
        if type(v) ~= "number" then
          error(string.format("Entry '%s' in sumItemParameters must be a number. Got type '%s' instead", k, type(v)))
        end
        local v2 = item.parameters[k]
        if type(v2) ~= "number" then
          error(string.format("Parameter '%s' in item is not a number. Got type '%s' instead", k, type(v2)))
        end
        item.parameters[k] = v + v2
      end
      player.giveEssentialItem(upgrade.essentialSlot, item)
      player.giveItem(config.getParameter("upgradedBeamaxeName"))
    else
      local itemName = "v-" .. upgrade.essentialSlot .. "slotemptynotifier"
      player.giveItem(itemName)
      return
    end
  end

  if upgrade.sumStatusProperties then
    for k, v in pairs(upgrade.sumStatusProperties) do
      if type(v) ~= "number" then
        error(string.format("Entry '%s' in sumStatusProperties must be a number. Got type '%s' instead", k, type(v)))
      end
      local v2 = status.statusProperty(k, 0)
      if type(v2) ~= "number" then
        error(string.format("Status property '%s' in item is not a number. Got type '%s' instead", k, type(v2)))
      end
      status.setStatusProperty(k, v + v2)
    end
  end

  mm = player.essentialItem("beamaxe")
  assert(mm, "MM magically disappeared. Not good.")
  mm.parameters.upgrades = mm.parameters.upgrades or {}
  table.insert(mm.parameters.upgrades, upgradeName)
  player.giveEssentialItem("beamaxe", mm)
  if consumeOnUse then
    item.consume(1)
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
