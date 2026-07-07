require "/scripts/util.lua"
require "/scripts/v-util.lua"
require "/scripts/vec2.lua"

local oldInit = init or function() end
local oldUpdate = update or function() end

local meterSpacing
local meterYOffset

local activeMeters
local meters  -- A mapping of identifiers to VDrawableMeter objects

function init()
  oldInit()

  message.setHandler("v-drawableMeter-show", function(_, _, name)
    v_drawableMeters_show(name)
  end)

  message.setHandler("v-drawableMeter-hide", function(_, _, name)
    v_drawableMeters_hide(name)
  end)

  message.setHandler("v-drawableMeter-setFillRatio", function(_, _, name, ratio)
    v_drawableMeters_setFillRatio(name, ratio)
  end)

  message.setHandler("v-drawableMeter-invoke", function(_, _, name, method, ...)
    v_drawableMeters_invoke(name, method, ...)
  end)

  local cfg = root.assetJson("/v-drawablemeters.config")

  meterSpacing = cfg.meterSpacing
  meterYOffset = cfg.meterYOffset

  activeMeters = {}
  meters = {}

  -- Initialize each meter.
  for name, meterConfig in pairs(cfg.meters) do
    local class = _ENV[meterConfig.class]
    meterConfig.config.baseOffset = {0, 0}
    meters[name] = class:new(meterConfig.config)

    meters[name]:init()
  end
end

function update(dt)
  localAnimator.clearDrawables()

  oldUpdate(dt)

  for _, meter in pairs(meters) do
    meter:update(dt)
  end
end

function v_drawableMeters_show(name)
  if not meters[name] then
    sb.logError("v-drawablemeters: Meter with name '%s' not found.", name)
    return
  end

  -- Show the meter and then update offsets if not done already.
  if not contains(activeMeters, name) then
    table.insert(activeMeters, name)
    meters[name]:show()

    v_drawableMeters_updateMeterOffsets()
  end
end

function v_drawableMeters_hide(name)
  if not meters[name] then
    sb.logError("v-drawablemeters: Meter with name '%s' not found.", name)
    return
  end

  -- Find location of the name to be removed.
  local removeIndex = nil
  for i, otherName in ipairs(activeMeters) do
    if otherName == name then
      removeIndex = i
      break
    end
  end

  -- Hide the meter and then update offsets if not done already.
  if removeIndex then
    table.remove(activeMeters, removeIndex)
    meters[name]:hide()

    v_drawableMeters_updateMeterOffsets()
  end
end

function v_drawableMeters_setFillRatio(name, ratio)
  if not meters[name] then
    sb.logError("v-drawablemeters: Meter with name '%s' not found.", name)
    return
  end

  meters[name]:setFillRatio(ratio)
end

function v_drawableMeters_invoke(name, method, ...)
  if not meters[name] then
    sb.logError("v-drawablemeters: Meter with name '%s' not found.", name)
    return
  end

  local meter = meters[name]

  if not meter[method] then
    sb.logError("v-drawablemeters: Meter with name '%s' does not have method '%s'", name, method)
    return
  end

  -- Invoke the method with name `method`, passing in corresponding arguments.
  meter[method](meter, ...)
end

function v_drawableMeters_updateMeterOffsets()
  local startXOffset = -meterSpacing * (#activeMeters - 1) / 2
  for i, name in ipairs(activeMeters) do
    local meter = meters[name]
    local xOffset = startXOffset + meterSpacing * (i - 1)

    meter:setOffset({xOffset, meterYOffset})
  end
end

---@class VDrawableMeter.Layer
---@field image string
---@field zLevel number?
---@field offset Vec2F?

---@class VDrawableMeter
---@field baseLayer VDrawableMeter.Layer
---@field fillLayer VDrawableMeter.Layer
---@field renderLayer string
---@field baseOffset Vec2F
---
---@field offset Vec2F
---@field size Vec2I
---
---@field drawables {drawable: Drawable, zLevel: number}[]
---@field active boolean
---@field fillRatio number
VDrawableMeter = {renderLayer = "overlay+5", images = {}}

function VDrawableMeter:new(obj)
  obj = obj or {}
  setmetatable(obj, self)
  self.__index = self
  return obj
end

function VDrawableMeter:init()
  self.size = root.imageSize(self.baseLayer.image)
  self.offset = vec2.add(self.baseOffset, vec2.mul(self.size, -1 / 16))
  self.drawables = {}

  self.active = false
  self.fillRatio = 0
end

function VDrawableMeter:update(dt)
  -- Show meter if active
  if self.active then
    self:_updateAnim(dt)
  end

  self:_draw()
end

function VDrawableMeter:show()
  self.active = true
end

function VDrawableMeter:hide()
  self.active = false
end

function VDrawableMeter:setFillRatio(ratio)
  self.fillRatio = ratio
end

function VDrawableMeter:setOffset(offset)
  self.offset = vec2.add(offset, vec2.mul(self.size, -1 / 16))
end

---Adds a drawable.
---@param layer VDrawableMeter.Layer
---@param transformer? fun(drawable: Drawable): Drawable
function VDrawableMeter:addDrawable(layer, transformer)
  local drawable = {
    image = layer.image,
    position = vec2.add(self.offset, layer.offset or {0, 0}),
    fullbright = true,
    centered = false
  }
  if transformer then
    drawable = transformer(drawable)
  end
  table.insert(self.drawables, {drawable = drawable, zLevel = layer.zLevel or 0})
end

function VDrawableMeter:_updateAnim(dt)
  self:addDrawable(self.baseLayer)

  local cropHeight = math.floor(self.size[2] * self.fillRatio)

  self:addDrawable(self.fillLayer, function(drawable)
    drawable.image = drawable.image .. string.format("?crop=0;0;%d;%d", self.size[1], cropHeight)
    return drawable
  end)
end

function VDrawableMeter:_draw()
  table.sort(self.drawables, function(a, b) return a.zLevel < b.zLevel end)

  for _, drawable in ipairs(self.drawables) do
    localAnimator.addDrawable(drawable.drawable, self.renderLayer)
  end

  self.drawables = {}
end

---@class VDepthPoisonMeter: VDrawableMeter
---@field flashLayer VDrawableMeter.Layer
---@field warningLayer VDrawableMeter.Layer
---@field shimmerLayer VDrawableMeter.Layer
---@field flashTime number
---@field warningPulseTime number
---@field warningThreshold number
---@field shimmerFrameCount integer
---
---@field shouldShimmer boolean
---@field shimmerTime number?
---@field flashTimer number
---@field shimmerTimer number
---@field warningPulseTimer number
VDepthPoisonMeter = VDrawableMeter:new()

function VDepthPoisonMeter:init()
  VDrawableMeter.init(self)

  self.shouldShimmer = false
  self.shimmerTime = nil
  self.flashTimer = 0
  self.shimmerTimer = 0
  self.warningPulseTimer = self.warningPulseTime
end

function VDepthPoisonMeter:update(dt)
  VDrawableMeter.update(self, dt)

  if self.active then
    self:_updateTimers(dt)
    self:_drawShimmer(dt)
  end
end

function VDepthPoisonMeter:setShimmerTime(time)
  if time then
    self.shouldShimmer = true
    self.shimmerTime = time
  else
    self.shouldShimmer = false
    self.shimmerTimer = 0
  end
end

function VDepthPoisonMeter:flash()
  self.flashTimer = self.flashTime
end

function VDepthPoisonMeter:_updateAnim(dt)
  VDrawableMeter._updateAnim(self, dt)

  local warningOpacity = math.floor(util.lerp(vUtil.pingPong(self.warningPulseTimer / self.warningPulseTime), 0, 255))

  self:addDrawable(self.warningLayer, function(drawable)
    drawable.image = drawable.image .. string.format("?multiply=ffffff%02x", warningOpacity)
    return drawable
  end)

  local flashOpacity = math.floor(util.lerp(self.flashTimer / self.flashTime, 0, 255))

  self:addDrawable(self.flashLayer, function(drawable)
    drawable.image = drawable.image .. string.format("?multiply=ffffff%02x", flashOpacity)
    return drawable
  end)
end

function VDepthPoisonMeter:_updateTimers(dt)
  self.flashTimer = math.max(0, self.flashTimer - dt)

  if self.fillRatio >= self.warningThreshold then
    self.warningPulseTimer = self.warningPulseTimer - dt
    if self.warningPulseTimer <= 0 then
      self.warningPulseTimer = self.warningPulseTime
    end
  else
    self.warningPulseTimer = self.warningPulseTime
  end
end

function VDepthPoisonMeter:_drawShimmer(dt)
  if self.shouldShimmer then
    self.shimmerTimer = self.shimmerTimer + dt
    if self.shimmerTimer > self.shimmerTime then
      self.shimmerTimer = 0
    end

    local frameNumber = math.floor(util.lerp(self.shimmerTimer / self.shimmerTime, 0, self.shimmerFrameCount))
    self:addDrawable(self.shimmerLayer, function(drawable)
      drawable.image = string.format("%s:%d", drawable.image, frameNumber)
      return drawable
    end)
  end
end

---@class VFreezingMeter: VDrawableMeter
---@field warningLayer VDrawableMeter.Layer
---@field warningPulseTime number
---@field warningThreshold number
---@field shimmerLayer VDrawableMeter.Layer
---@field shimmerFrameCount integer
---@field warmthLayer VDrawableMeter.Layer
---@field warmthFrameCount integer
---@field warmthCycleTime number
---@field frozenLayer VDrawableMeter.Layer
---@field frozenFrameCount integer
---@field frozenCycleTime number
---
---@field shouldShimmer boolean
---@field shimmerTime number?
---@field warningPulseTimer number
---@field shimmerTimer number
---@field warmthTimer number
---@field isWarm boolean
VFreezingMeter = VDrawableMeter:new()

function VFreezingMeter:init()
  VDrawableMeter.init(self)

  self.shouldShimmer = false
  self.shimmerTime = nil
  self.flashTimer = 0
  self.shimmerTimer = 0
  self.warmthTimer = 0
  self.warningPulseTimer = self.warningPulseTime
end

function VFreezingMeter:update(dt)
  VDrawableMeter.update(self, dt)

  if self.active then
    self:_updateTimers(dt)
    self:_drawShimmer(dt)
    self:_drawWarmth(dt)
    self:_drawFrozen(dt)
  end
end

function VFreezingMeter:setShimmerTime(time)
  if time then
    self.shouldShimmer = true
    self.shimmerTime = time
  else
    self.shouldShimmer = false
    self.shimmerTimer = 0
  end
end

function VFreezingMeter:setWarmth(isWarm)
  self.isWarm = isWarm
end

function VFreezingMeter:setFrozen(isFrozen)
  self.isFrozen = isFrozen
end

function VFreezingMeter:_updateAnim(dt)
  VDrawableMeter._updateAnim(self, dt)

  local warningOpacity = math.floor(util.lerp(vUtil.pingPong(self.warningPulseTimer / self.warningPulseTime), 0, 255))

  self:addDrawable(self.warningLayer, function(drawable)
    drawable.image = drawable.image .. string.format("?multiply=ffffff%02x", warningOpacity)
    return drawable
  end)
end

function VFreezingMeter:_updateTimers(dt)
  if self.fillRatio >= self.warningThreshold then
    self.warningPulseTimer = self.warningPulseTimer - dt
    if self.warningPulseTimer <= 0 then
      self.warningPulseTimer = self.warningPulseTime
    end
  else
    self.warningPulseTimer = self.warningPulseTime
  end
end

function VFreezingMeter:_drawShimmer(dt)
  if self.shouldShimmer then
    self.shimmerTimer = self.shimmerTimer + dt
    if self.shimmerTimer > self.shimmerTime then
      self.shimmerTimer = 0
    end

    local frameNumber = math.floor(util.lerp(self.shimmerTimer / self.shimmerTime, 0, self.shimmerFrameCount))
    self:addDrawable(self.shimmerLayer, function(drawable)
      drawable.image = string.format("%s:%d", drawable.image, frameNumber)
      return drawable
    end)
  end
end

function VFreezingMeter:_drawWarmth(dt)
  if self.isWarm then
    self.warmthTimer = math.min(self.warmthCycleTime, self.warmthTimer + dt)
  else
    self.warmthTimer = math.max(0, self.warmthTimer - dt)
  end

  if self.warmthTimer > 0 then
    local frameNumber = math.min(math.floor(util.lerp(self.warmthTimer / self.warmthCycleTime, 0, self.warmthFrameCount)), self.warmthFrameCount - 1)
    self:addDrawable(self.warmthLayer, function(drawable)
      drawable.image = string.format("%s:%d", drawable.image, frameNumber)
      return drawable
    end)
  end
end

function VFreezingMeter:_drawFrozen(dt)
  if self.isFrozen then
    self.frozenTimer = math.min(self.frozenCycleTime, self.frozenTimer + dt)
  else
    self.frozenTimer = 0
  end

  if self.frozenTimer > 0 then
    local frameNumber = math.min(math.floor(util.lerp(self.frozenTimer / self.frozenCycleTime, 0, self.frozenFrameCount)), self.frozenFrameCount - 1)
    self:addDrawable(self.frozenLayer, function(drawable)
      drawable.image = string.format("%s:%d", drawable.image, frameNumber)
      return drawable
    end)
  end
end