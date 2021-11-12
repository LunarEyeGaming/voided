function init()
  if storage.state == nil then storage.state = config.getParameter("defaultLightState", 2) end

  self.interactive = config.getParameter("interactive", true)
  object.setInteractive(self.interactive)

  if config.getParameter("inputNodes") then
    processWireInput()
  end

  setLightState(storage.state)
end

function onNodeConnectionChange(args)
  processWireInput()
end

function onInputNodeChange(args)
  processWireInput()
end

function onInteraction(args)
  if not config.getParameter("inputNodes") or not object.isInputNodeConnected(0) then
    storage.interState = not storage.interState
    
    setLightState(storage.state)
  end
end

function processWireInput()
  if object.isInputNodeConnected(0) then
    object.setInteractive(false)
    storage.state = (object.getInputNodeLevel(0) and 1 or 0) + (object.getInputNodeLevel(1) and 1 or 0)  -- Set to the number of active inputs.
    setLightState(storage.state)
  elseif self.interactive then
    object.setInteractive(true)  -- Maybe make this cycle between the three states if no inputs are given. Have this be a spare input that alternates between true and false otherwise. If both are connected, make this not interactive.
  end
end

function setLightState(newState)
  animator.setAnimationState("light", "state" .. newState)
  if animator.hasSound("state" .. newState) then
    animator.playSound("state" .. newState)
  end
end
