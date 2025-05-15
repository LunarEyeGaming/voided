require "/scripts/rect.lua"
require "/scripts/vec2.lua"

--- Utility functions related to the world.
vWorld = {}

---A constant list of vectors in the four cardinal directions.
---@type [Vec2I, Vec2I, Vec2I, Vec2I]
vWorld.ADJACENT_TILES = {{1, 0}, {0, 1}, {-1, 0}, {0, -1}}

---The size of each sector.
vWorld.SECTOR_SIZE = 32

-- Certain scripts may not work under specific script contexts due to some built-in tables being
-- unavailable. The legend below is intended to help in knowing when using each function is appropriate.
-- * = works under any script context
-- # = requires certain Starbound tables. See each table's documentation for more details at
--     Starbound/doc/lua/ or https://starbounder.org/Modding:Lua/Tables

--[[
  Requirements: #world

  Same as world.sendEntityMessage, except it checks if the entity exists before sending the message. This is necessary
  as sending messages to nonexistent entities can cause a segfault / access violation error.
]]
function vWorld.sendEntityMessage(entityId, messageType, ...)
  if world.entityExists(entityId) then
    return world.sendEntityMessage(entityId, messageType, ...)
  end
end

---Returns a random position in the given `region` that meets the given `predicate` within `maxAttempts` attempts, or
---`nil` if more than `maxAttempts` attempts are made.
---@param region RectF a rectangle in world coordinates
---@param predicate fun(position: Vec2F): boolean the condition that must be met for the position to be "valid"
---@param maxAttempts integer the maximum number of attempts allowed. Required if `predicate` is given.
---@return Vec2F?
function vWorld.randomPositionInRegion(region, predicate, maxAttempts)
  -- Attempt to find a random point that meets the predicate within maxAttempts attempts.
  local pos
  local attempts = 0
  repeat
    pos = rect.randomPoint(region)
    attempts = attempts + 1
  until attempts > maxAttempts or predicate(pos)

  -- If the loop above stopped because more than maxAttempts attempts were made...
  if attempts > maxAttempts then
    return nil
  end

  return pos
end

---Returns whether or not the given position is adjacent to a solid tile.
---@param position Vec2F
---@return boolean
function vWorld.isGroundAdjacent(position)
  -- Go through all the spaces adjacent to the position and return true if any of them are occupied by a tile.
  for _, offset in ipairs(vWorld.ADJACENT_TILES) do
    if world.material({position[1] + offset[1], position[2] + offset[2]}, "foreground") then
      return true
    end
  end

  return false
end

---Performs `raycastCount` equally spaced raycasts in a radial formation around a `center`, each having a
---`minRaycastLength` and a `maxRaycastLength`. The result is a list of items each containing an `angle` at which the
---raycast was performed and the resulting `position`. Raycasts without a collision are not included.
---@param args {raycastCount: integer, center: Vec2F, minRaycastLength: number, maxRaycastLength: number,
---collisionSet: CollisionSet?}
---@return {angle: number, position: Vec2F, magnitude: number}[]
function vWorld.radialRaycast(args)
  ---@type {angle: number, position: Vec2F, magnitude: number}[]
  local results = {}

  for i = 0, args.raycastCount - 1 do
    local angle = 2 * math.pi * i / args.raycastCount

    -- Attempt raycast
    local raycast = world.lineCollision(args.center, vec2.add(args.center, vec2.withAngle(angle, args.maxRaycastLength)))
    -- If successful...
    if raycast then
      -- If the distance from the target to the raycast exceeds args.minRaycastLength...
      local magnitude = world.magnitude(args.center, raycast)
      if magnitude >= args.minRaycastLength then

        table.insert(results, {angle = angle, position = raycast, magnitude = magnitude})
      end
    end
  end

  return results
end

--- Utility coroutine functions related to the world.
vWorldA = {}

--[[
  Requirements: #world, must be called in a coroutine

  Sends multiple entity messages of the given `messageType`, supplied with arguments, to `targets`, calling
  `successCallback` if the corresponding promise succeeds and calling `errorCallback` otherwise.

  param successCallback: the function to call when a promise succeeds. Signature: successCallback(promise, id)
    promise: the promise captured
    id: the ID of the entity associated with the promise captured
  param errorCallback: the function to call when a promise fails
  param targets: the entity IDs to which to send the message
  param messageType: the type of message to send
  remaining params: the arguments to supply to the message
]]
function vWorldA.sendEntityMessageToTargets(successCallback, errorCallback, targets, messageType, ...)
  local promiseIdAssocs = {}

  -- Probably unnecessary, but I have the gut feeling that the return times of each promise can vary.
  for _, target in ipairs(targets) do
    table.insert(promiseIdAssocs, {promise = vWorld.sendEntityMessage(target, messageType, ...), id = target})
  end

  for _, promiseIdAssoc in ipairs(promiseIdAssocs) do
    -- If a promise was returned...
    if promiseIdAssoc.promise then
      local promise = promiseIdAssoc.promise
      local id = promiseIdAssoc.id

      -- Wait for the promise to finish.
      while not promise:finished() do
        coroutine.yield()
      end

      if promise:succeeded() then
        successCallback(promise, id)
      else
        errorCallback(promise, id)
      end
    end
  end
end