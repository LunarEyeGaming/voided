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

---@class VDrawableMeter
---@field baseLayerImage string
---@field fillLayerImage string
---@field renderLayer string
---@field baseOffset Vec2F
---
---@field offset Vec2F
---@field size Vec2I
---
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
  self.size = root.imageSize(self.baseLayerImage)
  self.offset = vec2.add(self.baseOffset, vec2.mul(self.size, -1 / 16))

  self.active = false
  self.fillRatio = 0
end

function VDrawableMeter:update(dt)
  -- Show meter if active
  if self.active then
    self:_updateAnim(dt)
  end
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

function VDrawableMeter:_updateAnim(dt)
  localAnimator.addDrawable({
    image = self.baseLayerImage,
    position = self.offset,
    fullbright = true,
    centered = false
  }, self.renderLayer)

  local cropHeight = math.floor(self.size[2] * self.fillRatio)

  localAnimator.addDrawable({
    image = self.fillLayerImage .. string.format("?crop=0;0;%d;%d", self.size[1], cropHeight),
    position = self.offset,
    fullbright = true,
    centered = false
  }, self.renderLayer)
end

---@class VDepthPoisonMeter: VDrawableMeter
---@field flashLayerImage string
---@field warningLayerImage string
---@field shimmerLayerImage string
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

  localAnimator.addDrawable({
    image = self.warningLayerImage .. string.format("?multiply=ffffff%02x", warningOpacity),
    position = self.offset,
    fullbright = true,
    centered = false
  }, self.renderLayer)

  local flashOpacity = math.floor(util.lerp(self.flashTimer / self.flashTime, 0, 255))

  localAnimator.addDrawable({
    image = self.flashLayerImage .. string.format("?multiply=ffffff%02x", flashOpacity),
    position = self.offset,
    fullbright = true,
    centered = false
  }, self.renderLayer)
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
    localAnimator.addDrawable({
      image = string.format("%s:%d", self.shimmerLayerImage, frameNumber),
      position = self.offset,
      fullbright = true,
      centered = false
    }, self.renderLayer)
  end
end