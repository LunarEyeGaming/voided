require "/scripts/util.lua"

local fadeColor
local fadeMax
local colorFadeTime
local disappearTime

local state

local exitId

function init()
  fadeColor = config.getParameter("fadeColor")
  fadeMax = config.getParameter("fadeMax")
  colorFadeTime = config.getParameter("colorFadeTime")
  disappearTime = config.getParameter("disappearTime")

  animator.setAnimationState("blink", "blinkout")
  animator.playSound("activate")
  effect.addStatModifierGroup({{stat = "activeMovementAbilities", amount = 1}, {stat = "invulnerable", amount = 1}})
  mcontroller.addMomentum({0, 50})

  message.setHandler("v-riftlinkentrance-setExitId", function(_, _, exitId_)
    exitId = exitId_
  end)

  state = coroutine.create(statusCourse)
end

function update(dt)
  if coroutine.status(state) == "dead" then
    effect.expire()
  else
    local status, result = coroutine.resume(state)
    if not status then error(result) end
  end
end

function statusCourse()
  -- Apply color fade
  local timer = 0
  util.wait(colorFadeTime, function(dt)
    local fade = (timer / colorFadeTime) * fadeMax
    effect.setParentDirectives(string.format("fade=%s=%.2f", fadeColor, fade))
    timer = timer + dt
  end)

  -- Then fade out of existence
  timer = 0
  util.wait(disappearTime, function(dt)
    local alpha = math.max(math.floor(((disappearTime - timer) / disappearTime) * 255), 0)
    effect.setParentDirectives(string.format("?multiply=ffffff%02x?fade=%s=%.2f", alpha, fadeColor, fadeMax))
    timer = timer + dt
  end)

  teleport()

  -- Reappear
  timer = 0
  util.wait(disappearTime, function(dt)
    local alpha = math.max(math.floor((1 - (disappearTime - timer) / disappearTime) * 255), 0)
    effect.setParentDirectives(string.format("?multiply=ffffff%02x?fade=%s=%.2f", alpha, fadeColor, fadeMax))
    timer = timer + dt
  end)

  -- Apply color fade
  timer = 0
  util.wait(colorFadeTime, function(dt)
    local fade = (1 - (timer / colorFadeTime)) * fadeMax
    effect.setParentDirectives(string.format("fade=%s=%.2f", fadeColor, fade))
    timer = timer + dt
  end)
end

function teleport()
  sb.logInfo("%s, %s", exitId, world.entityExists(exitId))
  if exitId and world.entityExists(exitId) then
    local teleportTarget = world.callScriptedEntity(exitId, "teleportPosition", mcontroller.collisionPoly())
    if teleportTarget then
      mcontroller.setPosition(teleportTarget)
    end
  end

  effect.setParentDirectives("")
  animator.setAnimationState("blink", "blinkin")
end

function uninit()

end
