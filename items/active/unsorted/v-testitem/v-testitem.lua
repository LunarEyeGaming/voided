require "/scripts/actions/v-sensor.lua"

local projectileId

function init()
  activeItem.setScriptedAnimationParameter("riftTrails", config.getParameter("riftTrails"))
  activeItem.setScriptedAnimationParameter("riftTrailDuration", config.getParameter("riftTrailDuration"))
end

function update(dt)
  if projectileId then
    if world.entityExists(projectileId) then
      world.sendEntityMessage(projectileId, "updateProjectile", activeItem.ownerAimPosition())
    else
      projectileId = nil
      activeItem.setScriptedAnimationParameter("riftTrailTrackingEntity", nil)
    end
  end
end

function activate()
  -- activeItem.interact("ScriptPane", root.assetJson("/interface/scripted/voideye-tier6skip/voideye-tier6skip.config"))
  projectileId = world.spawnProjectile("v-stuttertest", activeItem.ownerAimPosition(), entity.id(), {1, 0}, false, {controlMovement = {maxSpeed = 50, controlForce = 1000}})
  activeItem.setScriptedAnimationParameter("riftTrailTrackingEntity", projectileId)
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