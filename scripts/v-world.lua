require "/scripts/rect.lua"

--- Utility functions related to the world.
vWorld = {}

--- Utility coroutine functions related to the world.
vWorldA = {}

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