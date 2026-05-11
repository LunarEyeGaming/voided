require "/scripts/v-vec2.lua"

vPursueState = {}

function vPursueState.enter()
  if not self.target or not targetValid(self.target) then
    return nil
  end

  return { timer = config.getParameter("pursueTime") }
end

function vPursueState.enteringState(stateData)
  -- sb.logInfo("Entering attack state")
end

function vPursueState.update(dt, stateData)
  if not self.target then return true end

  stateData.timer = stateData.timer - dt

  local toTarget = entity.distanceToEntity(self.target)

  if stateData.moveCoroutine and coroutine.status(stateData.moveCoroutine) ~= "dead" then
    coroutine.resume(stateData.moveCoroutine)
  else
    stateData.moveCoroutine = coroutine.create(turnAndBoost(toTarget,
    config.getParameter("pursueBoostDelay"),
    config.getParameter("pursueBoostDuration"),
    config.getParameter("pursueBoostSpeed")))
  end

  return vec2.mag(toTarget) <= config.getParameter("attackMaxDistance") and stateData.timer <= 0
end

function vPursueState.leavingState(stateData)
end