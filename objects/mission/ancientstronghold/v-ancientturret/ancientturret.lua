require "/scripts/util.lua"

function init()
  self.angles
  self.currentAngle
  self.halfFov
  self.sightRadius
  self.waitTime
  self.turnTime

  self.state = FSM:new()
  self.state2 = FSM:new() -- Queries
end

function update()
  self.state:update()
end

function noop()
  while true do
    coroutine.yield()
  end
end

function turnLoop()
  while true do
    for _, angle in pairs(self.angles) do
      turn(angle, self.turnTime)
      wait()
    end
    coroutine.yield()
  end
end

function turn(angle, turnTime)
  local startAngle = self.currentAngle
  local timer = 0
  util.wait(turnTime, function(dt)
    timer = math.min(timer + dt, turnTime)
    local curAngle = util.lerp(timer / turnTime, 0, angle)
    setAngle(curAngle)
  end)
end

function wait()
  util.wait(self.waitTime)
end

function setAngle(angle)
  self.currentAngle = angle
  animator.resetTransformationGroup("gun")
  animator.rotateTransformationGroup("gun", angle)
end

function getTarget()
  local queried = world.entityQuery(object.position(), self.sightRadius)
  -- Iterate through each queried entity. Find the first one that is within its field of view (ordered from nearest to farthest)
  
end