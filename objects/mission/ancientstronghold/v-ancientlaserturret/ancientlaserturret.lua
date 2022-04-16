require "/scripts/util.lua"
require "/scripts/poly.lua"
require "/scripts/vec2.lua"

function init()
  self.turnTime1 = config.getParameter("turnTime1")
  self.turnTime2 = config.getParameter("turnTime2")
  self.resetTime = config.getParameter("resetTime")
  self.endDelay = config.getParameter("endDelay")
  self.windupTime = config.getParameter("windupTime")
  self.defaultAngle = util.toRadians(config.getParameter("defaultAngle"))
  setAngle(self.defaultAngle)
  self.beamLength = config.getParameter("beamLength")
  self.beamOffset = config.getParameter("beamOffset")
  self.damageConfig = config.getParameter("damageConfig")

  message.setHandler("attack", function(_, _, startAngle, endAngle)
    self.state:set(states.fire, util.toRadians(startAngle), util.toRadians(endAngle))
  end)

  self.state = FSM:new()
end

function update(dt)
  self.state:update()
end

states = {}
function states.noop()
  while true do
    coroutine.yield()
  end
end

function states.fire(startAngle, endAngle)
  local timer = 0
  util.wait(self.turnTime1, function(dt)
    timer = math.min(timer + dt, self.turnTime1)
    local curAngle = util.lerp(timer / self.turnTime1, self.defaultAngle, startAngle)
    setAngle(curAngle)
  end)
  
  animator.setAnimationState("laser", "windup")
  util.wait(self.windupTime)
  animator.setAnimationState("laser", "active")
  
  -- Fire laser
  timer = 0
  util.wait(self.turnTime2, function(dt)
    timer = math.min(timer + dt, self.turnTime2)
    local curAngle = util.lerp(timer / self.turnTime2, startAngle, endAngle)
    local damageConfig = copy(self.damageConfig)
    damageConfig.poly = poly.translate({{0, 0}, vec2.rotate({self.beamLength, 0}, curAngle)}, self.beamOffset)
    object.setDamageSources({damageConfig})
    setAngle(curAngle)
  end)
  
  util.wait(self.endDelay)

  object.setDamageSources()
  animator.setAnimationState("laser", "winddown")

  timer = 0
  util.wait(self.resetTime, function(dt)
    timer = math.min(timer + dt, self.resetTime)
    local curAngle = util.lerp(timer / self.resetTime, endAngle, self.defaultAngle)
    setAngle(curAngle)
  end)
  
  states.noop()
end

-- FUNCTIONS

function setAngle(angle)
  --self.currentAngle = angle
  animator.resetTransformationGroup("gun")
  animator.rotateTransformationGroup("gun", angle)
end