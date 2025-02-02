require "/scripts/util.lua"
require "/scripts/vec2.lua"

local speed
local arc
local targetPos

function init()
  speed = 15
  arc = {}
end

function update(dt)
  if targetPos then
    world.debugPoint(targetPos, "green")
  end
  for i = 1, #arc - 1 do
    world.debugLine(arc[i], arc[i + 1], "green")
  end
end

function activate()
  arc = {}
  targetPos = activeItem.ownerAimPosition()
  local toTarget = world.distance(targetPos, mcontroller.position())
  local gravityMultiplier = 1
  local aimVector = vec2.norm(util.aimVector(toTarget, speed, gravityMultiplier, false))
  -- Simulate the arc
  local velocity = vec2.mul(aimVector, speed)
  local startArc = mcontroller.position()
  local x = 0
  while x < math.abs(toTarget[1]) do
    local time = x / math.abs(velocity[1])
    local yVel = velocity[2] - (gravityMultiplier * world.gravity(mcontroller.position()) * time)
    local step = vec2.add({util.toDirection(aimVector[1]) * x, ((velocity[2] + yVel) / 2) * time}, mcontroller.position())

    startArc = step
    table.insert(arc, startArc)
    local arcVector = vec2.norm({velocity[1], yVel})
    x = x + math.abs(arcVector[1])
  end
end

function aStarAlgorithm(startPoint, endPoint)
  local exploredPoints = {}
  local queue = {}  -- Priority queue, sorted by cost (actual distance + Euclidean distance). Each entry contains the position and the cost.
  local distances = {}  -- Distance of each position from the startPoint. Hash map
  local predecessors = {}  -- The predecessor of each position. Hash map

  ---Inserts a position into the priority queue, or updates it if it is already in the queue.
  ---@param positionHash string
  ---@param cost number
  local insertToQueue = function(positionHash, cost)
    -- Traverse through the queue in descending order, shifting elements until we find the right one. If the element to
    -- insert is already in the queue,
    local i = #queue
    -- while
  end

  --[[
    Algorithm:
    explored = {}
    queue = new Queue({position = startPoint, cost = distance(startPoint, endPoint)})
    distances = {}  -- nil means infinity
    predecessors = {}  -- predecessor of each position. nil = no predecessor.
    while queue is not empty:
      next = queue.remove()  -- Remove from queue
      explored.push(next)
      for each neighbor of next:
        if distances[next] + distance > ???
  ]]
end