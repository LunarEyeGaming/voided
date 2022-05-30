require "/scripts/util.lua"

function init()
  OVERHEATED = 0
  INACTIVE = 1
  ACTIVE = 2

  self.detectArea = config.getParameter("detectArea")
  self.detectArea[1] = object.toAbsolutePosition(self.detectArea[1])
  self.detectArea[2] = object.toAbsolutePosition(self.detectArea[2])

  storage.state = storage.state or config.getParameter("startingState", OVERHEATED)

  message.setHandler("cooldown", function()
    storage.state = INACTIVE
    animator.setAnimationState("console", "off")
  end)
  
  message.setHandler("activate", function()
    storage.state = ACTIVE
    animator.setAnimationState("console", "turnon")
    object.setLightColor(config.getParameter("lightColor", {255, 255, 255}))
  end)

  message.setHandler("isActive", function()
    return storage.state == ACTIVE
  end)

  if storage.state == ACTIVE then
    animator.setAnimationState("console", "on")
    object.setLightColor(config.getParameter("lightColor", {255, 255, 255}))
  elseif storage.state == INACTIVE then
    animator.setAnimationState("console", "off")
    object.setLightColor({0, 0, 0, 0})
  else
    animator.setAnimationState("console", "overheated")
    object.setLightColor({0, 0, 0, 0})
  end
  
  animator.setGlobalTag("destination", "v-ancientstronghold")
end

function onInteraction()
  if storage.state == OVERHEATED then
    return {config.getParameter("overheatedInteractAction"), config.getParameter("overheatedInteractData")}
  elseif storage.state == INACTIVE then
    return {config.getParameter("inactiveInteractAction"), config.getParameter("inactiveInteractData")}
  else
    return {config.getParameter("interactAction"), config.getParameter("interactData")}
  end
end

function update(dt)
  if storage.state == ACTIVE then
    local players = world.entityQuery(self.detectArea[1], self.detectArea[2], {
        includedTypes = {"player"},
        boundMode = "CollisionArea"
      })

    if #players > 0 and animator.animationState("portal") == "closed" then
      animator.setAnimationState("portal", "open")
      animator.playSound("on")
      object.setLightColor(config.getParameter("lightColor", {255, 255, 255}))
    elseif #players == 0 and animator.animationState("portal") == "openloop" then
      animator.setAnimationState("portal", "close")
      animator.playSound("off")
      object.setLightColor({0, 0, 0, 0})
    end
  end
end
