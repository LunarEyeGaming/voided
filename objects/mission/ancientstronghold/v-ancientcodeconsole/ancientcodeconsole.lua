local expCode
local numInputs
local wrongPulseDuration
local digitRevolveRadius
local pulseTimer
local nextPartNum
local inCode
local finished
local activeInput

function init()
  expCode = config.getParameter("expectedCode")
  numInputs = #config.getParameter("inputNodes")
  wrongPulseDuration = config.getParameter("wrongPulseDuration")
  digitRevolveRadius = config.getParameter("digitRevolveRadius")
  pulseTimer = nil
  nextPartNum = 1
  inCode = {}
  finished = false
  activeInput = nil

  CORRECT_NODE = numInputs  -- Output node for indicating that the code is correct
  INCORRECT_NODE = numInputs + 1  -- Output node for indicating that the code is incorrect
  
  updateAnimation()
end

function update(dt)
  if pulseTimer then
    pulseTimer = pulseTimer - dt
    if pulseTimer <= 0 then
      object.setOutputNodeLevel(INCORRECT_NODE, false)
      pulseTimer = nil
      reset()
    end
  end
end

function onInputNodeChange(args)
  -- TODO: Handle case where an input node gets deactivated while activeInput is nil such that activeInput does not get set. Also, do it in a way that doesn't produce spaghetti code.
  if pulseTimer or finished then return end  -- Lock inputs while sending pulse
  if not args.level then
    object.setOutputNodeLevel(args.node, false)
  end
  if noNodesActive() and activeInput then
    pushActiveInput()
    return
  end
  if activeInput then return end
  activeInput = args.node
  object.setOutputNodeLevel(args.node, args.level)  -- Edge case where the input node gets deactivated while activeInput is nil
end

function noNodesActive()
  for i = 0, numInputs - 1 do
    if object.getInputNodeLevel(i) then
      return false
    end
  end
  
  return true
end

function pushActiveInput()
  table.insert(inCode, activeInput)
  animator.setAnimationState("input" .. nextPartNum, activeInput)
  nextPartNum = nextPartNum + 1
  activeInput = nil
  if #inCode == #expCode then
    evalInCode()
  end
end

function evalInCode()
  res = matchInCode()
  if res then
    object.setOutputNodeLevel(CORRECT_NODE, true)
    finished = true
  else
    pulseTimer = wrongPulseDuration  -- Send a pulse to indicate that the code is wrong.
    object.setOutputNodeLevel(INCORRECT_NODE, true)
  end
end

function matchInCode()
  for i, expected in ipairs(expCode) do
    if expected ~= inCode[i] then
      return false
    end
  end
  
  return true
end

function reset()
  inCode = {}
  nextPartNum = 1
  for i = 1, #expCode do
    animator.setAnimationState("input" .. i, "inactive")
  end
end

function updateAnimation()
  for i = 1, #expCode do
    local angle = 2 * math.pi * (-i + 1) / #expCode + math.pi / 2
    local offset = {digitRevolveRadius * math.cos(angle), digitRevolveRadius * math.sin(angle)}
    animator.resetTransformationGroup("input" .. i)
    animator.translateTransformationGroup("input" .. i, offset)
  end
end