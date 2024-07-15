require "/scripts/util.lua"

local inactiveTime
local windupTime
local activeTime

local inactiveTimer
local windupTimer
local activeTimer

function init()
  inactiveTime = config.getParameter("inactiveTime", {2, 5})
  windupTime = 0.5
  activeTime = 0.5

  inactiveTimer = util.randomInRange(inactiveTime)
  windupTimer = nil
  activeTimer = nil

  -- Deactivate damage box in case it is already active.
  object.setDamageSources()
end

function update(dt)
  -- If the object is in the inactive state...
  if inactiveTimer then
    inactiveTimer = inactiveTimer - dt

    -- If the object has finished being inactive...
    if inactiveTimer <= 0 then
      -- Move to windup state.
      inactiveTimer = nil
      windupTimer = windupTime

      animator.setAnimationState("wire", "activating")
    end
  -- Otherwise, if the object is in the windup state...
  elseif windupTimer then
    windupTimer = windupTimer - dt

    -- If the object has finished telegraphing...
    if windupTimer <= 0 then
      -- Move to active state.
      windupTimer = nil
      activeTimer = activeTime

      -- Activate damage box
      object.setDamageSources({
        {
          poly = { {0.25, 1}, {0.75, 1}, {0.75, -1}, {0.25, -1} },
          damage = 1 * root.evalFunction("monsterLevelPowerMultiplier", object.level()),
          damageSourceKind = "electric",
          teamType = "environment"
        }
      })

      animator.setAnimationState("wire", "active")
    end
  -- Otherwise, if the object is in the active state...
  elseif activeTimer then
    activeTimer = activeTimer - dt

    -- If the object has finished being active...
    if activeTimer <= 0 then
      -- Move to inactive state
      activeTimer = nil
      inactiveTimer = util.randomInRange(inactiveTime)

      -- Deactivate damage box
      object.setDamageSources()

      animator.setAnimationState("wire", "inactive")
    end
  end
end