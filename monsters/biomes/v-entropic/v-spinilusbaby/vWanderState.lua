require "/scripts/v-vec2.lua"

vWanderState = {}

function vWanderState.enter()
  if self.target then return nil end

  return { }
end

function vWanderState.enteringState(stateData)
  -- sb.logInfo("Entering attack state")
end

function vWanderState.update(dt, stateData)
  if self.target then return true end

  if stateData.moveCoroutine and coroutine.status(stateData.moveCoroutine) ~= "dead" then
    coroutine.resume(stateData.moveCoroutine)
  else
    local direction = vec2.withAngle(math.random() * 2 * math.pi)
    stateData.moveCoroutine = coroutine.create(turnAndBoost(direction,
    config.getParameter("wanderBoostDelay"),
    config.getParameter("wanderBoostDuration"),
    config.getParameter("wanderBoostSpeed"),
    config.getParameter("wanderWaitTime")))
  end

  return false
end

function vWanderState.leavingState(stateData)
end