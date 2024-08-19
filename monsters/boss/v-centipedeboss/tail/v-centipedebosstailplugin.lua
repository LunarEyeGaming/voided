local m_invulnerable

local oldInit = init or function() end
local oldUpdate = update or function() end

function init()
  oldInit()

  m_invulnerable = false

  message.setHandler("setPhase", function(_, _, phase)
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
end

function update(dt)
  oldUpdate(dt)

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