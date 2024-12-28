vWorld = {}

vWorldA = {}  -- Async (requires coroutine)

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