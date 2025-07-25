--[[
  This module adds functionality for creating projectiles that can merge with each other. This can include projectiles
  of different types as well as projectiles of the same types.

  The `VMerger` class is for sending merge requests, while the `vMergeHandler` table is for receiving merge requests. If
  the projectile sending the merge requests and the projectile receiving the merge requests are the same, then you put
  both in the same script. Otherwise, put them in different scripts.
]]

---@class VMerger
---@field _queryArgs table
---@field _mergeRange number
---@field _dieOnMerge boolean?
---@field _mergeMultiple boolean
---
---@field _promises RpcPromise<any>[]
---@field _isMerged boolean
VMerger = {}

---Instantiates a merger.
---@param kind string the type of merger it is. Use in conjunction with `vMergeHandler.set`'s `kind` argument.
---@param mergeRange number the maximum range at which projectiles to merge are detected
---@param mergeMultiple boolean whether or not to send merge requests to multiple queried projectiles.
---@param dieOnMerge? boolean whether or not to kill the current projectile on a merge request.
---@return VMerger
function VMerger:new(kind, mergeRange, mergeMultiple, dieOnMerge)
  local instance = {
    _queryArgs = {
      callScript = "vMergeHandler._hasType",
      callScriptArgs = {kind},
      includedTypes = {"projectile"},
      order = "nearest",
      withoutEntityId = entity.id()
    },
    _mergeRange = mergeRange,
    _dieOnMerge = dieOnMerge,
    _mergeMultiple = mergeMultiple,

    _promises = {},
    _isMerged = false
  }

  setmetatable(instance, self)
  self.__index = self

  return instance
end

---Broadcasts merge requests, then returns the list of results for requests that finished. Call on each tick.
---
---If `_dieOnMerge` is `true`, then the projectile dies immediately after a merge.
---@param ... any (optional) the arguments to forward to the message.
---@return any[]
function VMerger:process(...)
  self:_broadcast(...)
  return self:_processPromises()
end

---Returns whether or not the projectile has merged.
---@return boolean
function VMerger:isMerged()
  return self._isMerged
end

---Helper method. Broadcasts a merge message to merge handlers.
---@param ... any the arguments to forward to the message.
function VMerger:_broadcast(...)
  local pos = mcontroller.position()
  local queried = world.entityQuery(pos, self._mergeRange, self._queryArgs)

  if self._mergeMultiple then
    local hasJustMerged = false
    -- Merge with other projectiles
    for _, id in ipairs(queried) do
      if world.magnitude(world.entityPosition(id), pos) < self._mergeRange then
        table.insert(self._promises, world.sendEntityMessage(id, "v-handleMerge", entity.id(), ...))
        hasJustMerged = true
      end
    end

    if hasJustMerged and self._dieOnMerge then
      projectile.die()
      self._isMerged = true
    end
  else
    if #queried > 0 and world.magnitude(world.entityPosition(queried[1]), mcontroller.position()) < self._mergeRange then
      table.insert(self._promises, world.sendEntityMessage(queried[1], "v-handleMerge", entity.id(), ...))
      if self._dieOnMerge then
        projectile.die()
        self._isMerged = true
      end
    end
  end
end

---Helper method. Goes through the promises that finished, removes them, and aggregates the results of the promises that
---succeeded.
---@return any[]
function VMerger:_processPromises()
  local results = {}

  for i = #self._promises, 1, -1 do
    local promise = self._promises[i]

    -- If a promise finished, handle its result and remove it.
    if promise:finished() then
      if promise:succeeded() then
        local result = promise:result()

        -- If the projectile accepted the message, add the result
        if result then
          table.insert(results, promise:result())
        end

        self._isMerged = true
      end

      table.remove(self._promises, i)
    end
  end

  return results
end

---@class vMergeHandler
---@field _kind string
---@field isMerged boolean READ-ONLY; DO NOT MODIFY
vMergeHandler = {}

---Sets the handler for merging the current projectile.
---@param kind string the merge kind to match. Should be the same as the one specified in a VMerger instance.
---@param resolveMergeConflicts? boolean whether or not to resolve merge conflicts via comparison of entity IDs. Set to `true` if your projectiles can send merge requests to each other.
---@param onMerge fun(...: any): boolean, any a function that receives the source entity followed by the arguments forwarded from the merge request.
function vMergeHandler.set(kind, resolveMergeConflicts, onMerge)
  vMergeHandler._kind = kind
  vMergeHandler.isMerged = false
  message.setHandler("v-handleMerge", function(_, _, sourceId, ...)
    -- The second comparison is arbitrary and is solely to handle conflicts when two projectiles send merge requests to
    -- each other.
    if not vMergeHandler.isMerged and (not resolveMergeConflicts or entity.id() < sourceId) then
      local status, result = onMerge(sourceId, ...)

      if status then
        projectile.die()
        vMergeHandler.isMerged = true
        return result
      end
    end
  end)
end

---Helper function. Returns whether or not the projectile handles merge requests of the given `kind`.
---@param kind string
---@return boolean
function vMergeHandler._hasType(kind)
  return vMergeHandler._kind == kind
end