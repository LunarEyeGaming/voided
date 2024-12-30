require "/monsters/boss/v-centipedeboss/v-sharedfunctions.lua"

local m_invulnerable
local deathCoroutine

local oldInit = init or function() end
local oldUpdate = update or function() end

function init()
  oldInit()

  m_invulnerable = false

  message.setHandler("activatePhase2Warning", function()
    animator.setAnimationState("body", "warning")

    animator.playSound("alarm", -1)
  end)

  message.setHandler("setPhase", function(_, _, phase)
    -- Do transition if the phase is set to 2.
    if phase == "2" then
      animator.setAnimationState("body", "transition")
      animator.stopAllSounds("alarm")
    else
      -- Otherwise, simply reset
      animator.setAnimationState("body", "idle")
    end
    animator.setGlobalTag("phase", phase)
  end)

  message.setHandler("setInvulnerable", function(_, _, invulnerable)
    m_invulnerable = invulnerable
    if invulnerable then
      -- Make invulnerable for a lot of time (but not math.huge b/c that causes problems)
      status.addEphemeralEffect("invulnerable", 2 ^ 32)
    else
      status.removeEphemeralEffect("invulnerable")
    end
  end)

  message.setHandler("dontDieYet", function()
    self.shouldDie = false
  end)

  message.setHandler("startDeathAnimation", function()
    deathCoroutine = coroutine.create(function()
      centipede.deathAnimation()

      coroutine.yield()  -- Wait one tick to ensure that the body segments die after, not before, the head.

      self.shouldDie = true
    end)
  end)
end

function update(dt)
  oldUpdate(dt)

  -- Run coroutine if defined.
  if deathCoroutine then
    -- If not dead...
    if coroutine.status(deathCoroutine) ~= "dead" then
      coroutine.resume(deathCoroutine)
    else
      deathCoroutine = nil
    end
  end

  -- terra_wormbodysimple sets damageOnTouch to true on every update, so we override this if m_invulnerable is true.
  monster.setDamageOnTouch(not m_invulnerable)
end

function getChildren()
  return {}
end

function getTail()
  return entity.id()
end

function trailAlongEllipse()
  -- Do nothing
end