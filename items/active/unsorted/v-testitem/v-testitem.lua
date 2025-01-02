require "/scripts/util.lua"
require "/scripts/vec2.lua"

function update(dt)
  -- local angle = vec2.angle(world.distance(activeItem.ownerAimPosition(), mcontroller.position()))
  -- local adjustedPos = adjustAgainstGeometry(activeItem.ownerAimPosition(), angle, 20, 100)
  -- world.debugPoint(adjustedPos, "green")
  -- local collidePoint = world.lineCollision(mcontroller.position(), adjustedPos)
  -- if collidePoint then
  --   world.debugLine(mcontroller.position(), collidePoint, "red")
  -- end
  -- collidePoint = world.lineCollision(mcontroller.position(), activeItem.ownerAimPosition())
  -- if collidePoint then
  --   world.debugLine(mcontroller.position(), collidePoint, "yellow")
  -- end

  do
    local searchParameters = {
      returnBest = false,
      mustEndOnGround = false,
      maxFScore = 400,
      maxNodesToSearch = 70000,
      boundBox = mcontroller.boundBox()
    }
    local results = world.findPlatformerPath(mcontroller.position(), activeItem.ownerAimPosition(), mcontroller.baseParameters(), searchParameters)
    world.debugText("%s", results, mcontroller.position(), "green")
  end
end

-- ---Returns the average of the positions resulting from a radial raycast of `rayCount` rays at position `position`, with
-- ---rays that are more parallel to the given angle having less weight than those that are perpendicular to it.
-- ---@param position Vec2F
-- ---@param angle number
-- ---@param rayCount integer
-- ---@param maxRaycastLength number
-- ---@return Vec2F
-- function adjustAgainstGeometry(position, angle, rayCount, maxRaycastLength)
--   local positionSum = {0, 0}

--   -- For each ray...
--   for i = 0, rayCount - 1 do
--     local rayAngle = 2 * math.pi * i / rayCount  -- Calculate angle.
--     local endPos = vec2.add(position, vec2.withAngle(rayAngle, maxRaycastLength))  -- Calculate end position
--     local raycast = world.lineCollision(position, endPos)  -- Perform collision test

--     local weight = math.abs(math.sin(util.angleDiff(rayAngle, angle)))  -- Calculate weight
--     -- Apply weight to raycast or endPos, whichever is defined.
--     local weightedPosition = vec2.add(vec2.mul(world.distance(raycast or endPos, position), weight), position)
--     -- Add to the sum of positions
--     positionSum = vec2.add(positionSum, weightedPosition)
--     -- positionSum = vec2.add(positionSum, raycast or endPos)
--   end

--   -- Divide this weighted sum by the number of positions (rayCount)
--   return vec2.mul(positionSum, 1 / rayCount)
-- end

-- function radialRaycast(position)
--   -- Find locations of tunnels by raycasting around the entity. Wherever there are changes in raycast distance that exceed
--   -- a threshold, these are tunnels. Massive increase in distance followed by a massive decrease in distance => a cluster.
--   -- Break it all up into contiguous blocks with these markers. If the blocks occupy a certain amount of vision, then use
--   -- a sweep. Otherwise, stop in the middle of the block.
--   -- A sweep consists of a start angle and an end angle.
--   -- Parameters: Angular velocity, wait time
--   local maxRaycastLength = 100
--   local rayCount = 20
--   local searchThreshold = 20  -- The minimum raycast distance necessary to add a search region
--   local raycastClusters = {}
--   local nextRaycastCluster = {}
--   local firstRaycastAdded = false
--   local lastRaycastAdded = false

--   for i = 0, rayCount - 1 do
--     local angle = 2 * math.pi * i / rayCount

--     local color
--     local raycastDistance
--     -- Attempt raycast
--     local raycast = world.lineCollision(position, vec2.add(position, vec2.withAngle(angle, maxRaycastLength)))
--     if raycast then
--       raycastDistance = world.magnitude(position, raycast)
--       world.debugText("%s", raycastDistance, raycast, "green")
--       color = "red"  -- Debug
--     else
--       raycastDistance = maxRaycastLength
--     end

--     -- If the raycast distance goes below the threshold and we are adding to the raycast cluster...
--     if raycastDistance < searchThreshold and #nextRaycastCluster > 0 then
--       table.insert(raycastClusters, nextRaycastCluster)  -- Push the next raycast cluster to the list.
--       nextRaycastCluster = {}  -- Clear nextRaycastCluster list
--     end

--     -- If the raycast distance exceeds the threshold or we are adding to the raycast cluster...
--     if raycastDistance > searchThreshold or #nextRaycastCluster > 0 then
--       -- If this is the first raycast...
--       if i == 1 then
--         firstRaycastAdded = true  -- Mark as added.
--       -- Otherwise, if this is the last raycast...
--       elseif i == rayCount then
--         lastRaycastAdded = true  -- Mark as added.
--       end
--       table.insert(nextRaycastCluster, angle)  -- Add to the next raycast cluster
--     end

--     -- Debug
--     if #nextRaycastCluster > 0 then
--       color = "green"
--     end

--     -- Debug
--     world.debugLine(position, vec2.add(position, vec2.withAngle(angle, raycastDistance)), color)

--   end

--   -- If there are some angles in the next cluster remaining...
--   if #nextRaycastCluster > 0 then
--     -- If the first angle and the last angle were added to a cluster...
--     if firstRaycastAdded and lastRaycastAdded then
--       -- Copy everything in the next raycast cluster to the beginning of the first cluster.
--       for _, angle in ipairs(nextRaycastCluster) do
--         table.insert(raycastClusters[1], 1, angle)
--       end
--     else
--       table.insert(raycastClusters, nextRaycastCluster)
--     end
--   end
--   return raycastClusters
-- end

-- function processRaycastClusters(raycastClusters)
--   -- Returns a sequence of sweep and spot searches.
--   -- Entries in each cluster must be sorted.
--   -- The minimum angular span of a raycast cluster necessary for it to become a sweep search instead of a spot search.
--   -- A sweep search consists of sweeping back and forth once.
--   -- A spot search consists of turning toward the center of the search zone and stopping for a brief moment.
--   local sweepThreshold = 2 * math.pi * 0.2
--   local searchZones = {}
--   for i, cluster in ipairs(raycastClusters) do
--     local startPos = activeItem.ownerAimPosition()
--     world.debugLine(startPos, vec2.add(startPos, vec2.withAngle(cluster[1], 20)), "yellow")
--     world.debugLine(startPos, vec2.add(startPos, vec2.withAngle(cluster[#cluster], 20)), "yellow")
--     world.debugText("#%s start", i, vec2.add(startPos, vec2.withAngle(cluster[1], 20)), "yellow")
--     world.debugText("#%s end", i, vec2.add(startPos, vec2.withAngle(cluster[#cluster], 20)), "yellow")
--     -- If the angular span of the cluster exceeds the sweep threshold...
--     if math.abs(util.angleDiff(cluster[1], cluster[#cluster])) > sweepThreshold then
--       -- Mark as a sweep.
--       for _, angle in ipairs(cluster) do
--         local endPos = vec2.add(startPos, vec2.withAngle(angle, 20))

--         world.debugLine(startPos, endPos, "blue")
--       end
--     else
--       -- Compute midpoint between the two edge angles of the cluster.
--       local middleAngle = (cluster[1] + cluster[#cluster]) / 2
--       local endPos = vec2.add(startPos, vec2.withAngle(middleAngle, 20))
--       world.debugLine(startPos, endPos, "orange")
--       world.debugText("#%s", i, endPos, "blue")
--     end
--   end
-- end

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