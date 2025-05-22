--[[

-- Two types of scenarios:
-- 1. The projectile wants to merge with another projectile of a different type.
-- 2. The projectile wants to merge with another projectile of the same type
-- In the first scenario, use Merger for the first projectile and MergeHandler for the second.
-- In the second scenario, use both.
-- Currently, only two projectiles are in the second group, and they both simply aggregate a result.
-- However, I plan on adding a third projectile to the second group that will, instead of aggregating a result, spawn a
-- new projectile in its place.
-- I may also make the sludge merge with itself. This will also require keeping track of a value.

class Merger
  const field _mergeRange: number  -- The range at which to broadcast merge requests.
  const field _dieOnMerge: boolean  -- Whether or not the projectile doing the merge request should die as well.

  field _promises: RpcPromise<any>[]  -- Internal list of promises.
  field _isMerged: boolean  -- Whether or not the projectile has merged.

  -- kind: The kind of merger. Use this to prevent merges from other projectiles.
  constructor(kind, mergeRange, dieOnMerge)

    self._mergeRange = mergeRange
    self._dieOnMerge = dieOnMerge

    self._promises = {}
    self._isMerged = false
  end

  -- Whether or not the projectile has merged.
  method isMerged() -> boolean
    return self._isMerged
  end

  method process() -> any[]  -- Broadcasts merge requests, then processes the promises. Returns the list of results.
    _broadcast()
    return _processPromises()
  end

  method _broadcast()
    local queried = world.entityQuery(mcontroller.position(), self.mergeRange, {
      callScript = "v_isMergerType",
      callScriptArgs = {self._kind},
      includedTypes = {"projectile"},
      order = "nearest"
    })

    -- Merge with other projectiles
    for _, id in ipairs(queried) do
      if world.magnitude(world.entityPosition(queried[1]), mcontroller.position()) < self.mergeRange then
        table.insert(mergePromises, world.sendEntityMessage(id, "v-handleMerge", entity.id()))
      end
    end
  end
  method _processPromises() -> any[]
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
        end

        table.remove(mergePromises, i)
      end
    end

    return results
  end
end

class MergeHandler
  field _kind: string  -- The kind of merger. Use this to prevent merges from other projectiles.
  field _isMerged: boolean
  field _onMerge: fun()

  method isMerged() -> boolean  -- Whether or not the projectile has merged.
end

class SelfMerger
  field _promises: RpcPromise<any>[]  -- Internal list of promises.
  field _kind: string  -- The kind of merger. Use this to prevent merges from other projectiles.
  field _mergeRange: number  -- The range at which to broadcast merge requests.
  field _dieOnMerge: false  -- Whether or not the projectile doing the merge request should die as well (which means it will send only one merge request).
  field _onMerge: fun()

  method process() -> any[]  -- Broadcasts merge requests, then processes the promises. Returns the list of results.

  method _broadcast()
  method _processPromises() -> any[]
end
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
---@param kind string
---@param mergeRange number
---@param mergeMultiple boolean
---@param dieOnMerge? boolean
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

---Broadcasts merge requests, then processes the promises. Returns the list of results.
---
---If _dieOnMerge is true, then the projectile dies immediately after a merge.
---@param ... any the arguments to forward to the message.
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

---Broadcasts a merge message to merge handlers.
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
---@param resolveMergeConflicts? boolean whether or not to resolve merge conflicts via comparison of entity IDs. Use if your projectiles can send merge requests to each other.
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

function vMergeHandler._hasType(kind)
  return vMergeHandler._kind == kind
end