---@class (exact) VTickDamage
---@field damageRequest DamageRequest
---@field interval number
---@field firstTickDelay number
---@field timer number
---@field __index VTickDamage
VTickDamage = {}

---@class VTickDamageNewArgs
---@field kind string
---@field amount number
---@field damageType DamageType
---@field source EntityId? Defaults to the current entity
---@field interval number
---@field firstTickDelay number? Defaults to `interval`

---Creates a new tick damage instance.
---@param args VTickDamageNewArgs
function VTickDamage:new(args)
  local objConfig = {
    damageRequest = {
      damageSourceKind = args.kind,
      damage = args.amount,
      damageType = args.damageType,
      sourceEntityId = args.source or entity.id()
    },
    interval = args.interval,
    firstTickDelay = args.firstTickDelay or args.interval,
    timer = args.firstTickDelay or args.interval
  }
  setmetatable(objConfig, self)
  self.__index = self

  return objConfig
end

---Runs the tick damage instance for one tick.
---@param dt number
function VTickDamage:update(dt)
  -- Decrement timer
  self.timer = self.timer - dt
  -- If timer reaches zero...
  if self.timer <= 0 then
    self.timer = self.interval
    self:_applyTickDamage()  -- Apply tick damage
  end
end

---Resets the timer.
function VTickDamage:reset()
  self.timer = self.firstTickDelay
end

---Helper method. Applies tick damage.
function VTickDamage:_applyTickDamage()
  status.applySelfDamageRequest(self.damageRequest)
end