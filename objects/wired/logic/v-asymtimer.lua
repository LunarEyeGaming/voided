-- "asymmetric timer"; script for timers with differing intervals when on vs off

function init()
  if storage.state == nil then
    output(false)
  else
    output(storage.state)
  end
  if storage.timer == nil then
    storage.timer = 0
  end
  self.onDuration = config.getParameter("onDuration")
  self.offDuration = config.getParameter("offDuration")
end

function output(state)
  if storage.state ~= state then
    storage.state = state
    object.setAllOutputNodes(state)
    if state then
      animator.setAnimationState("switchState", "on")
    else
      animator.setAnimationState("switchState", "off")
    end
  else
  end
end

function update(dt)
  if (not object.isInputNodeConnected(0)) or object.getInputNodeLevel(0) then
    if storage.timer == 0 then
      if storage.state then
        storage.timer = self.offDuration
      else
        storage.timer = self.onDuration
      end
      output(not storage.state)
    else
      storage.timer = storage.timer - 1 
    end
  else
    storage.timer = 0
    output(false)
  end
end
