-- Name: ancientcodeconsole.lua

function init()
  self.expCode = config.getParameter("expectedCode")
  self.numInputs = #config.getParameter("inputNodes")
  self.wrongPulseDuration = config.getParameter("wrongPulseDuration")
  self.digitRevolveRadius = config.getParameter("digitRevolveRadius")
  self.pulseTimer = nil
  self.nextPartNum = 1
  self.timer = 0
  self.inCode = {}
  CORRECT_NODE = self.numInputs  -- Output node for indicating that the code is correct
  INCORRECT_NODE = self.numInputs + 1  -- Output node for indicating that the code is incorrect
  self.finished = false
  updateAnimation()
end

function update(dt)
  if self.pulseTimer then
    self.pulseTimer = self.pulseTimer - dt
    if self.pulseTimer <= 0 then
      object.setOutputNodeLevel(INCORRECT_NODE, false)
      self.pulseTimer = nil
      reset()
    end
  end
  
  self.timer = self.timer + dt
  
  world.debugText("Input Code: %s", self.inCode, object.position(), "green")
end

function onInputNodeChange(args)
  -- TODO: Handle case where an input node gets deactivated while self.activeInput is nil such that self.activeInput does not get set. Also, do it in a way that doesn't produce spaghetti code.
  if self.pulseTimer or self.finished then return end  -- Lock inputs while sending pulse
  if not args.level then
    object.setOutputNodeLevel(args.node, false)
  end
  if noNodesActive() and self.activeInput then
    pushActiveInput()
    return
  end
  if self.activeInput then return end
  self.activeInput = args.node
  object.setOutputNodeLevel(args.node, args.level)  -- Edge case where the input node gets deactivated while self.activeInput is nil
end

function noNodesActive()
  for i = 0, self.numInputs - 1 do
    if object.getInputNodeLevel(i) then
      return false
    end
  end
  
  return true
end

function pushActiveInput()
  table.insert(self.inCode, self.activeInput)
  animator.setAnimationState("input" .. self.nextPartNum, self.activeInput)
  self.nextPartNum = self.nextPartNum + 1
  self.activeInput = nil
  if #self.inCode == #self.expCode then
    evalInCode()
  end
end

function evalInCode()
  res = matchInCode()
  if res then
    object.setOutputNodeLevel(CORRECT_NODE, true)
    self.finished = true
  else
    self.pulseTimer = self.wrongPulseDuration  -- Send a pulse to indicate that the code is wrong.
    object.setOutputNodeLevel(INCORRECT_NODE, true)
  end
end

function matchInCode()
  for i, expected in ipairs(self.expCode) do
    if expected ~= self.inCode[i] then
      return false
    end
  end
  
  return true
end

function reset()
  self.inCode = {}
  self.nextPartNum = 1
  for i = 1, #self.expCode do
    animator.setAnimationState("input" .. i, "inactive")
  end
end

function updateAnimation()
  for i = 1, #self.expCode do
    local angle = 2 * math.pi * (-i + 1) / #self.expCode + math.pi / 2
    local offset = {self.digitRevolveRadius * math.cos(angle), self.digitRevolveRadius * math.sin(angle)}
    animator.resetTransformationGroup("input" .. i)
    animator.translateTransformationGroup("input" .. i, offset)
  end
end